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
    else
                     "order_#{to_state}"
    end

    # Use event name for title when it makes more sense
    title = case event&.to_s
    when "reopen"
             "Order reopened"
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

  def log_item_fulfilment_toggled(order_item:, enabled:, actor: nil)
    activity_type = enabled ? :item_fulfilment_enabled : :item_fulfilment_disabled
    title = enabled ? "Item fulfilment enabled" : "Item fulfilment disabled"
    description = "#{order_item.display_name} #{enabled ? 'enabled' : 'disabled'} for fulfilment"

    log_activity(
      activity_type: activity_type,
      title: title,
      description: description,
      metadata: {
        order_item_id: order_item.id,
        item_title: order_item.title,
        variant_title: order_item.variant_title,
        fulfilment_active: enabled
      },
      actor: actor
    )
  end

  def log_item_variant_mapping_added(order_item:, variant_mapping:, actor: nil)
    log_activity(
      activity_type: :item_variant_mapping_added,
      title: "Product & image selected",
      description: "#{order_item.display_name} mapped to #{variant_mapping.frame_sku_title}",
      metadata: {
        order_item_id: order_item.id,
        item_title: order_item.title,
        variant_mapping_id: variant_mapping.id,
        frame_sku_title: variant_mapping.frame_sku_title,
        image_filename: variant_mapping.image_filename
      },
      actor: actor
    )
  end

  def log_item_variant_mapping_updated(order_item:, variant_mapping:, actor: nil)
    log_activity(
      activity_type: :item_variant_mapping_updated,
      title: "Product & image updated",
      description: "#{order_item.display_name} mapping updated",
      metadata: {
        order_item_id: order_item.id,
        item_title: order_item.title,
        variant_mapping_id: variant_mapping.id,
        frame_sku_title: variant_mapping.frame_sku_title,
        image_filename: variant_mapping.image_filename
      },
      actor: actor
    )
  end

  def log_item_variant_mapping_replaced(order_item:, variant_mapping:, replaced_type:, actor: nil)
    type_label = replaced_type == "image" ? "Image" : "Product & image"

    log_activity(
      activity_type: :item_variant_mapping_replaced,
      title: "#{type_label} replaced",
      description: "#{order_item.display_name} mapping replaced",
      metadata: {
        order_item_id: order_item.id,
        item_title: order_item.title,
        variant_mapping_id: variant_mapping.id,
        frame_sku_title: variant_mapping.frame_sku_title,
        image_filename: variant_mapping.image_filename,
        replaced_type: replaced_type
      },
      actor: actor
    )
  end

  def log_item_removed(order_item:, actor: nil)
    log_activity(
      activity_type: :item_removed,
      title: "Item removed",
      description: "#{order_item.display_name} removed from order",
      metadata: {
        order_item_id: order_item.id,
        item_title: order_item.title,
        quantity: order_item.quantity
      },
      actor: actor
    )
  end

  def log_item_restored(order_item:, actor: nil)
    log_activity(
      activity_type: :item_restored,
      title: "Item restored",
      description: "#{order_item.display_name} restored to order",
      metadata: {
        order_item_id: order_item.id,
        item_title: order_item.title,
        quantity: order_item.quantity
      },
      actor: actor
    )
  end

  private

  attr_reader :order
end
