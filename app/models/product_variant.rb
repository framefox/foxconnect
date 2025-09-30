class ProductVariant < ApplicationRecord
  # Associations
  belongs_to :product
  has_many :variant_mappings, dependent: :destroy
  has_many :order_items, dependent: :nullify

  # Delegations for convenience
  delegate :platform, to: :product
  delegate :external_id, to: :product, prefix: true # product_external_id

  # Validations
  validates :title, :price, :external_variant_id, presence: true
  validates :price, numericality: { greater_than: 0 }
  validates :position, presence: true, uniqueness: { scope: :product_id }
  validates :external_variant_id, uniqueness: { scope: :product_id }
  validates :weight_unit, inclusion: { in: %w[kg g lb oz] }, allow_blank: true

  # Scopes
  scope :available, -> { where(available_for_sale: true) }
  scope :by_option, ->(option_name, value) {
    where("JSON_EXTRACT(selected_options, '$[*].name') = ? AND JSON_EXTRACT(selected_options, '$[*].value') = ?", option_name, value)
  }
  scope :ordered, -> { order(:position) }
  scope :with_compare_at_price, -> { where.not(compare_at_price: nil) }

  # Methods
  def display_name
    "#{product.title} - #{title}"
  end

  def option_value(option_name)
    selected_options.find { |opt| opt["name"] == option_name }&.dig("value")
  end

  def option_values_hash
    selected_options.each_with_object({}) do |option, hash|
      hash[option["name"]] = option["value"]
    end
  end

  def has_compare_at_price?
    compare_at_price.present? && compare_at_price > price
  end

  def discount_amount
    return 0 unless has_compare_at_price?
    compare_at_price - price
  end

  def discount_percentage
    return 0 unless has_compare_at_price?
    ((discount_amount / compare_at_price) * 100).round(2)
  end

  def shopify_gid
    return nil unless product.platform == "shopify"
    "gid://shopify/ProductVariant/#{external_variant_id}"
  end

  def platform_url
    case product.store.platform
    when "shopify"
      "https://#{product.store.shopify_domain}/admin/products/#{product.external_id}/variants/#{external_variant_id}"
    when "squarespace"
      # Future implementation
      nil
    when "wix"
      # Future implementation
      nil
    end
  end

  def weight_in_grams
    return nil unless weight.present?

    case weight_unit
    when "kg"
      weight * 1000
    when "g"
      weight
    when "lb"
      weight * 453.592
    when "oz"
      weight * 28.3495
    else
      weight
    end
  end

  def formatted_options
    selected_options.map { |opt| "#{opt['name']}: #{opt['value']}" }.join(", ")
  end

  # Get the default variant mapping for this product variant (not associated with any order item)
  def default_variant_mapping
    variant_mappings.where.not(id: OrderItem.select(:variant_mapping_id).where.not(variant_mapping_id: nil)).first
  end
end
