class Organization < ApplicationRecord
  # Associations
  has_many :users, dependent: :nullify
  has_many :stores, dependent: :destroy
  has_many :saved_items, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :uid, presence: true, uniqueness: true

  # Callbacks
  before_validation :generate_uid, on: :create

  private

  def generate_uid
    return if uid.present?

    # Generate a URL-friendly unique identifier
    base_uid = name.parameterize.presence || "org"
    candidate_uid = base_uid
    suffix = 1

    while Organization.exists?(uid: candidate_uid)
      candidate_uid = "#{base_uid}-#{suffix}"
      suffix += 1
    end

    self.uid = candidate_uid
  end
end
