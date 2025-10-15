class User < ApplicationRecord
  # Associations
  has_many :shopify_customers, dependent: :destroy
  has_many :stores, dependent: :nullify

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Helper methods
  def full_name
    "#{first_name} #{last_name}".strip.presence || email
  end
end
