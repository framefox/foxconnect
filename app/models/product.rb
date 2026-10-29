class Product < ApplicationRecord
  # Associations
  belongs_to :store
  has_many :product_variants, dependent: :destroy

  # Delegations for convenience
  delegate :platform, to: :store
  delegate :shopify_domain, to: :store, allow_nil: true

  # Validations
  validates :title, :handle, :external_id, presence: true
  validates :handle, uniqueness: { scope: :store_id }
  validates :external_id, uniqueness: { scope: :store_id }

  # Enums
  enum :status, { draft: "draft", active: "active", archived: "archived" }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :published, -> { where.not(published_at: nil) }
  scope :present_in_source, -> { where(removed_from_source_at: nil) }
  scope :removed_from_source, -> { where.not(removed_from_source_at: nil) }
  scope :by_platform, ->(platform) { joins(:store).where(stores: { platform: platform }) }
  scope :by_vendor, ->(vendor) { where(vendor: vendor) }
  scope :by_type, ->(type) { where(product_type: type) }

  # Callbacks
  before_validation :generate_handle, if: -> { handle.blank? && title.present? }

  # Methods
  # Keep older jobs from overwriting the status of a newer sync request.
  def record_mockup_sync(job_id, status, details = {}, new_request: false)
    with_lock do
      current_job = mockup_sync_result&.fetch("job_id", nil)
      return if !new_request && current_job.present? && current_job != job_id

      update!(mockup_sync_result: details.merge(
        "job_id" => job_id, "status" => status, "updated_at" => Time.current.iso8601
      ))
    end
  end

  def has_variants?
    product_variants.present_in_source.count > 1
  end

  def default_variant
    product_variants.present_in_source.order(:position).first
  end

  def price_range
    scoped_variants = product_variants.present_in_source
    return [ 0, 0 ] if scoped_variants.empty?

    prices = scoped_variants.pluck(:price)
    [ prices.min, prices.max ]
  end

  def min_price
    price_range.first
  end

  def max_price
    price_range.last
  end

  def price_varies?
    min_price != max_price
  end

  def compare_at_price_range
    scoped_variants = product_variants.present_in_source
    return [ nil, nil ] if scoped_variants.empty?

    compare_prices = scoped_variants.where.not(compare_at_price: nil).pluck(:compare_at_price)
    return [ nil, nil ] if compare_prices.empty?

    [ compare_prices.min, compare_prices.max ]
  end

  def available_for_sale?
    product_variants.present_in_source.any?(&:available_for_sale?)
  end

  def removed_from_source?
    removed_from_source_at.present?
  end

  def present_in_source?
    !removed_from_source?
  end

  def archive_from_source!(timestamp: Time.current)
    transaction do
      variants_archived = product_variants.present_in_source.update_all(
        removed_from_source_at: timestamp,
        updated_at: Time.current
      )
      product_archived = false

      unless removed_from_source?
        update!(removed_from_source_at: timestamp)
        product_archived = true
      end

      {
        product_archived: product_archived,
        variants_archived: variants_archived
      }
    end
  end

  def shopify_gid
    return nil unless platform == "shopify"
    "gid://shopify/Product/#{external_id}"
  end

  def platform_url
    case store.platform
    when "shopify"
      "https://#{store.shopify_domain}/admin/products/#{external_id}"
    when "squarespace"
      # Future implementation
      nil
    when "wix"
      # Future implementation
      nil
    end
  end

  # Helper method to check if product has variant mappings that can be synced
  def has_variant_mappings?
    product_variants.present_in_source.joins(:variant_mappings).exists?
  end

  # Get count of variant mappings for this product
  def variant_mappings_count
    VariantMapping.joins(:product_variant)
                  .where(product_variants: { product_id: id, removed_from_source_at: nil })
                  .count
  end

  # Page grids only need these two numbers. Preload them for a page of
  # products so the view does not load variant rows or count one product at a time.
  def self.preload_variant_counts(products)
    records = products.to_a
    records.each do |product|
      product.preloaded_active_variants_count = 0
      product.preloaded_total_variants_count = 0
    end
    return records if records.empty?

    by_id = records.index_by(&:id)
    ProductVariant.present_in_source.where(product_id: by_id.keys).group(:product_id).pluck(
      :product_id,
      Arel.sql("COUNT(*)"),
      Arel.sql("COUNT(*) FILTER (WHERE product_variants.fulfilment_active)")
    ).each do |product_id, total, active|
      product = by_id[product_id]
      product.preloaded_total_variants_count = total.to_i
      product.preloaded_active_variants_count = active.to_i
    end

    records
  end

  attr_accessor :preloaded_active_variants_count, :preloaded_total_variants_count

  # Get count of active variants for fulfillment
  def active_variants_count
    return preloaded_active_variants_count unless preloaded_active_variants_count.nil?

    product_variants.present_in_source.where(fulfilment_active: true).count
  end

  # Get total variants count
  def total_variants_count
    return preloaded_total_variants_count unless preloaded_total_variants_count.nil?

    product_variants.present_in_source.count
  end

  # Sync product fulfilment_active status with its variants
  # Product should be active if ANY variant is active
  def sync_fulfilment_status!
    should_be_active = product_variants.present_in_source.exists?(fulfilment_active: true)
    update_column(:fulfilment_active, should_be_active) if fulfilment_active != should_be_active
  end

  private

  def generate_handle
    self.handle = title.parameterize
  end
end
