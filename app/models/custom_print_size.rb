class CustomPrintSize < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :user, presence: true
  validates :long, presence: true, numericality: { greater_than: 0 }
  validates :short, presence: true, numericality: { greater_than: 0 }
  validates :unit, presence: true, inclusion: { in: %w[mm cm in] }
  validates :frame_sku_size_id, presence: true, numericality: { greater_than: 0 }
  validates :frame_sku_size_description, presence: true

  # Scopes
  scope :recent_first, -> { order(created_at: :desc) }

  # Helper methods
  def dimensions_display
    "#{format_dimension(long)}×#{format_dimension(short)}#{unit_display}"
  end

  def full_description
    "#{dimensions_display} (Priced as #{frame_sku_size_description})"
  end

  def unit_display
    unit == "in" ? '"' : unit
  end

  # Convert dimensions to millimeters for calculations
  def long_mm
    convert_to_mm(long)
  end

  def short_mm
    convert_to_mm(short)
  end

  # Helper to format dimension numbers (remove trailing zeros)
  def format_dimension(value)
    "%g" % ("%.2f" % value)
  end

  private

  # Convert a dimension to millimeters based on the unit
  def convert_to_mm(dimension)
    case unit
    when "mm"
      dimension.to_f
    when "cm"
      dimension.to_f * 10
    when "in"
      dimension.to_f * 25.4
    else
      dimension.to_f
    end
  end
end
