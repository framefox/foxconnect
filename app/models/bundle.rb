class Bundle < ApplicationRecord
  belongs_to :product_variant
  has_many :variant_mappings, dependent: :destroy

  validates :slot_count, presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10 }

  # Convenience method
  def multi_slot?
    slot_count > 1
  end
end

