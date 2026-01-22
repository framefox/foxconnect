class User < ApplicationRecord
  # Include Devise modules
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable

  # Associations
  belongs_to :organization, optional: true
  has_many :shopify_customers, dependent: :destroy
  has_many :created_stores, class_name: "Store", foreign_key: :created_by_user_id, dependent: :nullify, inverse_of: :created_by_user
  has_many :custom_print_sizes, dependent: :destroy

  # Delegate stores to organization for backwards compatibility
  # This allows current_user.stores to work as before
  def stores
    organization&.stores || Store.none
  end

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Override Devise's password_required? to make password optional for non-admin users
  # Admin users must have a password, but JWT handoff users (non-admins) don't need one
  def password_required?
    admin? && (encrypted_password.blank? || password.present?)
  end

  # Override email_changed? to prevent Devise reconfirmation logic
  # This prevents issues when creating users via JWT handoff
  def email_changed?
    false
  end

  # Helper methods
  def full_name
    "#{first_name} #{last_name}".strip.presence || email
  end

  def admin?
    admin == true
  end

  def country_name
    case country
    when "AU"
      "Australia"
    when "NZ"
      "New Zealand"
    else
      country
    end
  end
end
