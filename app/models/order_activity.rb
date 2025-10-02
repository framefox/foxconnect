class OrderActivity < ApplicationRecord
  belongs_to :order
  belongs_to :actor, polymorphic: true, optional: true

  # Activity types enum for better organization and querying
  enum :activity_type, {
    # Order state changes
    order_created: "order_created",
    order_draft: "order_draft",
    order_submitted: "order_submitted",
    order_awaiting_production: "order_awaiting_production",
    order_production_started: "order_production_started",
    order_in_production: "order_in_production",
    order_cancelled: "order_cancelled",
    order_reopened: "order_reopened",
    order_completed: "order_completed",

    # Production events
    sent_to_production: "sent_to_production",
    production_failed: "production_failed",

    # Fulfillment events
    item_fulfilled: "item_fulfilled",
    item_shipped: "item_shipped",

    # System events
    order_imported: "order_imported",
    order_resynced: "order_resynced",

    # Manual events
    note_added: "note_added",
    custom_event: "custom_event"
  }

  # Validations
  validates :activity_type, :title, :occurred_at, presence: true
  validates :metadata, presence: true

  # Scopes
  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_type, ->(type) { where(activity_type: type) }
  scope :with_actor, -> { where.not(actor_type: nil) }
  scope :system_events, -> { where(actor_type: nil) }

  # Helper methods
  def has_actor?
    actor_type.present? && actor_id.present?
  end

  def system_event?
    !has_actor?
  end

  def time_ago
    return "just now" if occurred_at > 1.minute.ago
    return "#{time_diff_in_minutes} minutes ago" if occurred_at > 1.hour.ago
    return "#{time_diff_in_hours} hours ago" if occurred_at > 1.day.ago
    return "#{time_diff_in_days} days ago" if occurred_at > 1.week.ago
    occurred_at.strftime("%B %d, %Y at %I:%M %p")
  end

  def icon_class
    case activity_type
    when "order_created", "order_imported"
      "fa-plus-circle text-blue-500"
    when "order_draft"
      "fa-edit text-gray-500"
    when "order_submitted", "order_awaiting_production", "sent_to_production"
      "fa-paper-plane text-green-500"
    when "order_production_started", "order_in_production"
      "fa-play text-orange-500"
    when "order_cancelled"
      "fa-times-circle text-red-500"
    when "order_reopened"
      "fa-undo text-blue-500"
    when "order_completed"
      "fa-check-circle text-green-600"
    when "item_fulfilled", "item_shipped"
      "fa-truck text-purple-500"
    when "production_failed"
      "fa-exclamation-triangle text-red-500"
    when "note_added"
      "fa-comment text-gray-500"
    when "order_resynced"
      "fa-sync text-blue-400"
    else
      "fa-info-circle text-gray-400"
    end
  end

  private

  def time_diff_in_minutes
    ((Time.current - occurred_at) / 1.minute).round
  end

  def time_diff_in_hours
    ((Time.current - occurred_at) / 1.hour).round
  end

  def time_diff_in_days
    ((Time.current - occurred_at) / 1.day).round
  end
end
