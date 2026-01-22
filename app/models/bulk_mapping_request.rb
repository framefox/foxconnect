class BulkMappingRequest < ApplicationRecord
  belongs_to :store

  # Status enum
  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }

  # Validations
  validates :variant_title, presence: true
  validates :frame_sku_title, presence: true
  validates :total_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true

  # Serialize error_messages as JSON array
  serialize :error_messages, coder: JSON

  # Scopes
  scope :recent, -> { order(created_at: :desc) }

  # Methods
  def mark_processing!
    update!(status: :processing)
  end

  def mark_completed!(created_count:, skipped_count:, errors: [])
    update!(
      status: :completed,
      created_count: created_count,
      skipped_count: skipped_count,
      error_messages: errors
    )
  end

  def mark_failed!(error_message)
    update!(
      status: :failed,
      error_messages: [ error_message ]
    )
  end

  def has_errors?
    error_messages.present? && error_messages.any?
  end
end
