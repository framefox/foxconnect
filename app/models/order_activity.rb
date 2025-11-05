class OrderActivity < ApplicationRecord
  belongs_to :order
  belongs_to :actor, polymorphic: true, optional: true

  # Activity types enum for better organization and querying
  enum :activity_type, {
    # Order state changes
    order_created: "order_created",
    order_draft: "order_draft",
    order_submitted: "order_submitted",
    order_in_production: "order_in_production",
    order_cancelled: "order_cancelled",
    order_reopened: "order_reopened",
    order_completed: "order_completed",

    # Production events
    sent_to_production: "sent_to_production",
    production_failed: "production_failed",

    # Payment events
    payment: "payment",

    # Fulfillment events
    item_fulfilled: "item_fulfilled",
    item_shipped: "item_shipped",
    fulfillment_created: "fulfillment_created",
    fulfillment_updated: "fulfillment_updated",
    fulfillment_synced_to_shopify: "fulfillment_synced_to_shopify",
    fulfillment_sync_error: "fulfillment_sync_error",

    # Order item events
    item_fulfilment_enabled: "item_fulfilment_enabled",
    item_fulfilment_disabled: "item_fulfilment_disabled",
    item_variant_mapping_added: "item_variant_mapping_added",
    item_variant_mapping_updated: "item_variant_mapping_updated",
    item_variant_mapping_replaced: "item_variant_mapping_replaced",
    item_removed: "item_removed",
    item_restored: "item_restored",
    custom_item_added: "custom_item_added",

    # System events
    order_imported: "order_imported",
    order_resynced: "order_resynced",

    # Email events
    email_draft_imported: "email_draft_imported",
    email_fulfillment_notification: "email_fulfillment_notification",

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

  def icon_name
    case activity_type
    when "order_created", "order_imported"
      "PlusCircle"
    when "order_draft"
      "OrderDraft"
    when "order_submitted", "sent_to_production"
      "Order"
    when "order_in_production"
      "Play"
    when "order_cancelled"
      "Disabled"
    when "order_reopened"
      "Redo"
    when "order_completed"
      "CheckCircle"
    when "payment"
      "ReceiptPaid"
    when "item_fulfilled", "item_shipped"
      "PackageFulfilledIcon"
    when "fulfillment_created"
      "PackageFulfilledIcon"
    when "fulfillment_updated"
      "PackageFulfilledIcon"
    when "fulfillment_synced_to_shopify"
      "PackageFulfilledIcon"
    when "fulfillment_sync_error"
      "PackageFulfilledIcon"
    when "item_fulfilment_enabled"
      "PackageFulfilledIcon"
    when "item_fulfilment_disabled"
      "Disabled"
    when "item_variant_mapping_added", "item_variant_mapping_replaced"
      "Image"
    when "item_variant_mapping_updated"
      "Edit"
    when "item_removed"
      "MinusCircle"
    when "item_restored"
      "Redo"
    when "production_failed"
      "AlertTriangle"
    when "note_added"
      "Note"
    when "order_resynced"
      "Refresh"
    when "email_draft_imported", "email_fulfillment_notification"
      "EmailIcon"
    else
      "Info"
    end
  end

  def icon_color
    case activity_type
    when "order_created", "order_imported"
      "text-blue-500"
    when "order_draft"
      "text-gray-500"
    when "order_submitted", "sent_to_production"
      "text-green-500"
    when "order_in_production"
      "text-orange-500"
    when "order_cancelled"
      "text-red-500"
    when "order_reopened"
      "text-blue-500"
    when "order_completed"
      "text-green-600"
    when "payment"
      "text-green-600"
    when "item_fulfilled", "item_shipped"
      "text-purple-500"
    when "fulfillment_created"
      "text-green-500"
    when "fulfillment_updated"
      "text-blue-500"
    when "fulfillment_synced_to_shopify"
      "text-green-600"
    when "fulfillment_sync_error"
      "text-red-500"
    when "item_fulfilment_enabled"
      "text-green-500"
    when "item_fulfilment_disabled"
      "text-gray-500"
    when "item_variant_mapping_added", "item_variant_mapping_replaced"
      "text-blue-500"
    when "item_variant_mapping_updated"
      "text-blue-500"
    when "item_removed"
      "text-red-500"
    when "item_restored"
      "text-green-500"
    when "production_failed"
      "text-red-500"
    when "note_added"
      "text-gray-500"
    when "order_resynced"
      "text-blue-400"
    when "email_draft_imported", "email_fulfillment_notification"
      "text-purple-500"
    else
      "text-gray-400"
    end
  end
  
  def email_activity?
    email_draft_imported? || email_fulfillment_notification?
  end
  
  def email_type
    return nil unless email_activity?
    case activity_type
    when "email_draft_imported"
      "draft_imported"
    when "email_fulfillment_notification"
      "fulfillment_notification"
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
