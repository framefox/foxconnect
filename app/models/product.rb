class Product < ApplicationRecord
  # Associations
  has_many :product_variants, dependent: :destroy
  
  # Validations
  validates :title, :handle, :external_id, :platform, presence: true
  validates :handle, uniqueness: true
  validates :external_id, uniqueness: { scope: :platform }
  validates :platform, inclusion: { in: %w[shopify squarespace wix] }
  
  # Enums
  enum :status, { draft: 'draft', active: 'active', archived: 'archived' }
  enum :platform, { shopify: 'shopify', squarespace: 'squarespace', wix: 'wix' }
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :published, -> { where.not(published_at: nil) }
  scope :by_platform, ->(platform) { where(platform: platform) }
  scope :by_vendor, ->(vendor) { where(vendor: vendor) }
  scope :by_type, ->(type) { where(product_type: type) }
  
  # Callbacks
  before_validation :generate_handle, if: -> { handle.blank? && title.present? }
  
  # Methods
  def has_variants?
    product_variants.count > 1
  end
  
  def default_variant
    product_variants.order(:position).first
  end
  
  def price_range
    return [0, 0] if product_variants.empty?
    
    prices = product_variants.pluck(:price)
    [prices.min, prices.max]
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
    return [nil, nil] if product_variants.empty?
    
    compare_prices = product_variants.where.not(compare_at_price: nil).pluck(:compare_at_price)
    return [nil, nil] if compare_prices.empty?
    
    [compare_prices.min, compare_prices.max]
  end
  
  def available_for_sale?
    product_variants.any?(&:available_for_sale?)
  end
  
  def shopify_gid
    return nil unless platform == 'shopify'
    "gid://shopify/Product/#{external_id}"
  end
  
  def platform_url(store_domain = nil)
    case platform
    when 'shopify'
      return nil unless store_domain
      "https://#{store_domain}/admin/products/#{external_id}"
    when 'squarespace'
      # Future implementation
      nil
    when 'wix'
      # Future implementation
      nil
    end
  end
  
  private
  
  def generate_handle
    self.handle = title.parameterize
  end
end
