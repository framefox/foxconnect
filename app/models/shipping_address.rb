class ShippingAddress < ApplicationRecord
  # Associations
  belongs_to :order

  # Validations
  validates :order, presence: true, uniqueness: true

  # Instance methods
  def full_name
    if name.present?
      name
    elsif first_name.present? || last_name.present?
      "#{first_name} #{last_name}".strip
    else
      nil
    end
  end

  def full_address
    address_lines = [ address1, address2 ].compact.reject(&:blank?)
    location_parts = [ city, province, postal_code ].compact.reject(&:blank?)

    parts = []
    parts << address_lines.join(", ") if address_lines.any?
    parts << location_parts.join(", ") if location_parts.any?
    parts << country if country.present?
    parts << phone if phone.present?

    parts.join(", ")
  end

  def address_line_1
    address1
  end

  def address_line_2
    address2
  end

  def state
    province
  end

  def state_code
    province_code
  end

  def zip_code
    postal_code
  end

  def country_name
    country
  end

  def has_coordinates?
    latitude.present? && longitude.present?
  end

  def coordinates
    return nil unless has_coordinates?
    [ latitude, longitude ]
  end

  # Format for shipping labels
  def shipping_label_format
    lines = []
    lines << full_name if full_name.present?
    lines << company if company.present?
    lines << address1 if address1.present?
    lines << address2 if address2.present?

    city_line_parts = []
    city_line_parts << city if city.present?
    city_line_parts << province_code if province_code.present?
    city_line_parts << postal_code if postal_code.present?
    lines << city_line_parts.join(" ") if city_line_parts.any?

    lines << country if country.present?
    lines << phone if phone.present?
    lines
  end

  # Check if address appears to be international (non-US/CA)
  def international?
    return false unless country_code.present?
    !%w[US CA].include?(country_code.upcase)
  end

  # Check if required fields for shipping are present
  def shippable?
    full_name.present? &&
    address1.present? &&
    city.present? &&
    country.present?
  end
end
