class OrderActivityService
  def self.log_activity(order:, activity_type:, title:, description: nil, metadata: {}, actor: nil, occurred_at: Time.current)
    new(order: order).log_activity(
      activity_type: activity_type,
      title: title,
      description: description,
      metadata: metadata,
      actor: actor,
      occurred_at: occurred_at
    )
  end

  def initialize(order:)
    @order = order
  end

  def log_activity(activity_type:, title:, description: nil, metadata: {}, actor: nil, occurred_at: Time.current)
    activity = @order.order_activities.create!(
      activity_type: activity_type,
      title: title,
      description: description,
      metadata: metadata || {},
      actor: actor,
      occurred_at: occurred_at
    )

    Rails.logger.info "Logged activity for order #{@order.display_name}: #{activity_type} - #{title}"
    activity
  rescue => e
    Rails.logger.error "Failed to log activity for order #{@order.id}: #{e.message}"
    nil
  end

  # Convenience methods for common activities
  def log_state_change(from_state:, to_state:, event: nil, actor: nil)
    # Use event name for activity type when it makes more sense than the target state
    activity_type = case event&.to_s
    when "reopen"
                     "order_reopened"
    when "start_production"
                     "order_production_started"
    else
                     "order_#{to_state}"
    end

    # Use event name for title when it makes more sense
    title = case event&.to_s
    when "reopen"
             "Order reopened"
    when "start_production"
             "Order production started"
    else
             "Order #{to_state.to_s.humanize.downcase}"
    end

    log_activity(
      activity_type: activity_type,
      title: title,
      description: "Order state changed from #{from_state.to_s.humanize.downcase} to #{to_state.to_s.humanize.downcase}",
      metadata: { from_state: from_state, to_state: to_state, event: event },
      actor: actor
    )
  end

  def log_production_sent(production_result:, actor: nil)
    if production_result[:success]
      log_activity(
        activity_type: :sent_to_production,
        title: "Sent to production system",
        description: "Order successfully sent to production system",
        metadata: {
          shopify_draft_order_id: @order.shopify_remote_draft_order_id,
          target_dispatch_date: @order.target_dispatch_date&.to_s
        },
        actor: actor
      )
    else
      log_activity(
        activity_type: :production_failed,
        title: "Production submission failed",
        description: "Failed to send order to production system: #{production_result[:error]}",
        metadata: { error: production_result[:error] },
        actor: actor
      )
    end
  end

  def log_item_fulfilled(order_item:, actor: nil)
    log_activity(
      activity_type: :item_fulfilled,
      title: "Item fulfilled",
      description: "#{order_item.display_name} has been fulfilled",
      metadata: {
        order_item_id: order_item.id,
        item_title: order_item.title,
        quantity: order_item.quantity
      },
      actor: actor
    )
  end

  def log_note_added(note:, actor: nil)
    log_activity(
      activity_type: :note_added,
      title: "Note added",
      description: note,
      metadata: { note_length: note.length },
      actor: actor
    )
  end

  def log_order_imported(source_platform:, external_id:)
    log_activity(
      activity_type: :order_imported,
      title: "Order imported",
      description: "Order imported from #{source_platform.humanize}",
      metadata: {
        source_platform: source_platform,
        external_id: external_id,
        import_timestamp: Time.current
      }
    )
  end

  def log_order_resynced(actor: nil)
    log_activity(
      activity_type: :order_resynced,
      title: "Order resynced",
      description: "Order data resynced from platform",
      metadata: { resync_timestamp: Time.current },
      actor: actor
    )
  end

  private

  attr_reader :order
end
