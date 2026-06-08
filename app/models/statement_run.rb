class StatementRun < ApplicationRecord
  belongs_to :company
  has_many :statement_run_line_items, dependent: :destroy
  has_many :orders, through: :statement_run_line_items

  STATUSES = %w[pending sent archived].freeze

  validates :country_code, presence: true, inclusion: { in: CountryConfig.supported_countries }
  validates :currency, presence: true
  validates :period_start_on, :period_end_on, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(period_start_on: :desc, created_at: :desc) }
  scope :active, -> { where.not(status: "archived") }
  scope :archived, -> { where(status: "archived") }
  scope :pending, -> { where(status: "pending") }

  def total_amount
    total_amount_cents / 100.0
  end

  def archived?
    status == "archived"
  end

  def period_label
    "#{period_start_on.strftime('%d %b %Y')} - #{period_end_on.strftime('%d %b %Y')}"
  end
end
