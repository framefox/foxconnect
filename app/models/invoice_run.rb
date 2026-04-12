class InvoiceRun < ApplicationRecord
  belongs_to :company
  has_many :invoice_run_line_items, dependent: :destroy

  STATUSES = %w[draft sent archived].freeze

  validates :country_code, presence: true, inclusion: { in: CountryConfig.supported_countries }
  validates :currency, presence: true
  validates :invoice_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :active, -> { where.not(status: "archived") }
  scope :archived, -> { where(status: "archived") }

  def total_amount
    total_amount_cents / 100.0
  end

  def archived?
    status == "archived"
  end
end
