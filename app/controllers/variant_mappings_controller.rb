class VariantMappingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_product_variant, only: [ :create ]
  before_action :set_variant_mapping, only: [ :update, :destroy, :sync_to_shopify, :remove_image, :apply_image_to_all ]

  def create
    # Check if this is for a specific order item or for the product variant itself
    order_item_id = params[:order_item_id]

    if order_item_id.present?
      # Create a variant mapping specifically for this order item
      @order_item = OrderItem.joins(:order)
                             .merge(Order.for_organization(current_user.organization_id))
                             .find(order_item_id)

      # Create the image record if image data is provided
      image = find_or_create_image

      # Explicitly set is_default: false to prevent this order item mapping from becoming
      # the ProductVariant's default mapping
      @variant_mapping = VariantMapping.new(variant_mapping_params.merge(is_default: false, image: image))

      if @variant_mapping.save
        # Track if this was an existing mapping being replaced
        had_previous_mapping = @order_item.variant_mapping.present?

        # Associate this variant mapping only with the specific order item
        @order_item.update!(variant_mapping: @variant_mapping)

        # If apply_to_variant is true, also create/update the default variant mapping
        if params[:apply_to_variant] == true
          apply_to_default_variant_mapping(@variant_mapping)
        end

        # Log activity based on whether it's new or replacing existing
        if had_previous_mapping
          OrderActivityService.new(order: @order_item.order).log_item_variant_mapping_replaced(
            order_item: @order_item,
            variant_mapping: @variant_mapping,
            replaced_type: "full",
            actor: current_user
          )
        else
          OrderActivityService.new(order: @order_item.order).log_item_variant_mapping_added(
            order_item: @order_item,
            variant_mapping: @variant_mapping,
            actor: current_user
          )
        end

        variant_mapping_json = @variant_mapping.as_json(
          only: [
            :id, :frame_sku_id, :frame_sku_code, :slot_position,
            :frame_sku_title, :frame_sku_cost_cents, :preview_url,
            :frame_sku_description, :frame_sku_long, :frame_sku_short,
            :frame_sku_unit, :width, :height, :unit, :colour
          ],
          methods: [
            :image_id, :image_key, :cx, :cy, :cw, :ch, :cloudinary_id,
            :image_width, :image_height, :image_filename,
            :artwork_preview_thumbnail, :artwork_preview_medium, :artwork_preview_large,
            :framed_preview_thumbnail, :framed_preview_medium, :framed_preview_large,
            :frame_sku_cost_formatted, :frame_sku_cost_dollars, :dimensions_display
          ]
        )

        render json: variant_mapping_json, status: :created
      else
        render json: { errors: @variant_mapping.errors.full_messages }, status: :unprocessable_entity
      end
    else
      # Create/update variant mapping for the product variant
      bundle_id = variant_mapping_params[:bundle_id]
      slot_position = variant_mapping_params[:slot_position]

      # If bundle_id not provided, automatically use the product variant's bundle
      if bundle_id.blank? && @product_variant.present?
        bundle = @product_variant.bundle
        if bundle
          bundle_id = bundle.id
          slot_position = 1 # Single-slot bundles always use position 1
        else
          render json: { errors: [ "Product variant does not have a bundle" ] }, status: :unprocessable_entity
          return
        end
      end

      # Create the image record if image data is provided
      image = find_or_create_image

      # Ensure we have bundle_id and slot_position
      unless bundle_id.present? && slot_position.present?
        render json: { errors: [ "Bundle ID and slot position are required" ] }, status: :unprocessable_entity
        return
      end

      # Determine default behavior for bundle mappings
      bundle = @product_variant&.bundle
      is_default_for_bundle = bundle.present? && !bundle.multi_slot?

      # Find existing mapping for this bundle slot and country
      @variant_mapping = VariantMapping.find_by(
        bundle_id: bundle_id,
        slot_position: slot_position,
        country_code: variant_mapping_params[:country_code]
      )

      if @variant_mapping.present?
        # Update existing slot mapping
        @variant_mapping.image = image if image.present?
        success = @variant_mapping.update(variant_mapping_params.merge(
          product_variant_id: @product_variant.id,
          bundle_id: bundle_id,
          slot_position: slot_position,
          is_default: is_default_for_bundle
        ))
      else
        # Create new bundle slot mapping with product_variant_id
        @variant_mapping = VariantMapping.new(variant_mapping_params.merge(
          product_variant_id: @product_variant.id,
          bundle_id: bundle_id,
          slot_position: slot_position,
          image: image,
          is_default: is_default_for_bundle
        ))
        success = @variant_mapping.save
      end

      if success
        variant_mapping_json = @variant_mapping.as_json(
          only: [
            :id, :frame_sku_id, :frame_sku_code, :slot_position,
            :frame_sku_title, :frame_sku_cost_cents, :preview_url,
            :frame_sku_description, :frame_sku_long, :frame_sku_short,
            :frame_sku_unit, :width, :height, :unit, :colour
          ],
          methods: [
            :image_id, :image_key, :cx, :cy, :cw, :ch, :cloudinary_id,
            :image_width, :image_height, :image_filename,
            :artwork_preview_thumbnail, :artwork_preview_medium, :artwork_preview_large,
            :framed_preview_thumbnail, :framed_preview_medium, :framed_preview_large,
            :frame_sku_cost_formatted, :frame_sku_cost_dollars, :dimensions_display
          ]
        )

        render json: variant_mapping_json, status: @variant_mapping.previously_new_record? ? :created : :ok
      else
        render json: { errors: @variant_mapping.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  def update
    # Check if this variant mapping belongs to an order item
    order_item = @variant_mapping.order_items.first

    # Create the image record if image data is provided
    image = find_or_create_image
    @variant_mapping.image = image if image.present?

    update_params = variant_mapping_params

    if @variant_mapping.bundle.present?
      update_params = update_params.merge(
        is_default: !@variant_mapping.bundle.multi_slot?
      )
    end

    if @variant_mapping.update(update_params)
      # If apply_to_variant is true and this is an order item mapping, also update the default variant mapping
      if params[:apply_to_variant] == true && order_item.present?
        apply_to_default_variant_mapping(@variant_mapping)
      end

      # Log activity if this is for an order item
      if order_item.present?
        OrderActivityService.new(order: order_item.order).log_item_variant_mapping_replaced(
          order_item: order_item,
          variant_mapping: @variant_mapping,
          replaced_type: "image",
          actor: current_user
        )
      end

      variant_mapping_json = @variant_mapping.as_json(
        only: [
          :id, :frame_sku_id, :frame_sku_code, :slot_position,
          :frame_sku_title, :frame_sku_cost_cents, :preview_url,
          :frame_sku_description, :frame_sku_long, :frame_sku_short,
          :frame_sku_unit, :width, :height, :unit, :colour
        ],
        methods: [
          :image_id, :image_key, :cx, :cy, :cw, :ch, :cloudinary_id,
          :image_width, :image_height, :image_filename,
          :artwork_preview_thumbnail, :artwork_preview_medium, :artwork_preview_large,
          :framed_preview_thumbnail, :framed_preview_medium, :framed_preview_large,
          :frame_sku_cost_formatted, :frame_sku_cost_dollars, :dimensions_display
        ]
      )

      render json: variant_mapping_json, status: :ok
    else
      render json: { errors: @variant_mapping.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @variant_mapping.destroy
    render json: { message: "Variant mapping deleted successfully" }, status: :ok
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def sync_to_shopify
    # Determine the platform and call the appropriate sync method
    store = @variant_mapping.store
    platform = store.platform

    result = case platform
    when "shopify"
      @variant_mapping.sync_to_shopify_variant(size: 1000)
    when "squarespace"
      @variant_mapping.sync_to_squarespace_variant(size: 1000)
    when "wix"
      # Wix sync not yet implemented
      { success: false, error: "Image sync is not yet available for Wix stores" }
    else
      { success: false, error: "Unsupported platform: #{platform}" }
    end

    if result[:success]
      render json: {
        success: true,
        message: "Successfully synced image to #{platform.humanize} variant",
        action: result[:action],
        image_id: result[:image_id]
      }, status: :ok
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Error syncing variant mapping to #{store&.platform || 'platform'}: #{e.message}"
    render json: {
      success: false,
      error: "Failed to sync image: #{e.message}"
    }, status: :internal_server_error
  end

  def remove_image
    # Remove the image association but keep the variant mapping
    @variant_mapping.image = nil

    if @variant_mapping.save
      render json: {
        success: true,
        message: "Image removed from variant mapping"
      }, status: :ok
    else
      render json: {
        success: false,
        error: @variant_mapping.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Error removing image from variant mapping: #{e.message}"
    render json: {
      success: false,
      error: "Failed to remove image: #{e.message}"
    }, status: :internal_server_error
  end

  def apply_image_to_all
    # Get the source image from this variant mapping
    source_image = @variant_mapping.image

    unless source_image.present?
      render json: {
        success: false,
        error: "This variant mapping has no image to apply"
      }, status: :unprocessable_entity
      return
    end

    # Get the product through the product_variant
    product_variant = @variant_mapping.product_variant
    unless product_variant.present?
      render json: {
        success: false,
        error: "Variant mapping is not associated with a product variant"
      }, status: :unprocessable_entity
      return
    end

    product = product_variant.product
    country_code = @variant_mapping.country_code
    slot_position = @variant_mapping.slot_position

    # Find all other variant mappings in the same product with the same slot position and country code
    updated_count = 0
    skipped_count = 0

    product.product_variants.each do |pv|
      # Find mapping with same slot_position via bundle
      variant_mapping = pv.bundle&.variant_mappings&.find_by(
        slot_position: slot_position,
        country_code: country_code
      )

      next unless variant_mapping.present?

      # Skip the source mapping itself
      if variant_mapping.id == @variant_mapping.id
        skipped_count += 1
        next
      end

      # Create a copy of the source image for this mapping
      new_image = Image.create!(
        external_image_id: source_image.external_image_id,
        image_key: source_image.image_key,
        cloudinary_id: source_image.cloudinary_id,
        image_width: source_image.image_width,
        image_height: source_image.image_height,
        image_filename: source_image.image_filename,
        cx: source_image.cx,
        cy: source_image.cy,
        cw: source_image.cw,
        ch: source_image.ch
      )

      variant_mapping.update!(image: new_image)
      updated_count += 1
    end

    render json: {
      success: true,
      message: "Image applied to #{updated_count} variant#{'s' if updated_count != 1}",
      updated_count: updated_count,
      skipped_count: skipped_count
    }, status: :ok
  rescue => e
    Rails.logger.error "Error applying image to all variants: #{e.message}"
    render json: {
      success: false,
      error: "Failed to apply image: #{e.message}"
    }, status: :internal_server_error
  end

  private

  def set_product_variant
    # For custom order items, product_variant_id may be nil
    product_variant_id = params[:variant_mapping][:product_variant_id]

    if product_variant_id.present?
      # Ensure the product variant belongs to the user's organization's stores
      @product_variant = ProductVariant.joins(product: :store)
                                      .where(stores: { organization_id: current_user.organization_id })
                                      .find(product_variant_id)
    else
      # Allow nil for custom items - will be handled in create action
      @product_variant = nil
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Product variant not found" }, status: :not_found
  end

  def set_variant_mapping
    # Find the variant mapping and verify ownership
    @variant_mapping = VariantMapping.find(params[:id])

    # Check if user owns this variant mapping through any of these associations:
    # 1. Direct product_variant association (single/default mappings)
    # 2. Bundle template mappings (through bundle -> product_variant)
    # 3. Order item mappings (through order_items)

    user_owns_mapping = false

    # Check direct product_variant ownership (via organization)
    if @variant_mapping.product_variant.present?
      user_owns_mapping = @variant_mapping.product_variant.product.store.organization_id == current_user.organization_id
    end

    # Check bundle template ownership (via organization)
    if !user_owns_mapping && @variant_mapping.bundle.present?
      user_owns_mapping = @variant_mapping.bundle.product_variant.product.store.organization_id == current_user.organization_id
    end

    # Check order item ownership via organization
    if !user_owns_mapping && @variant_mapping.order_items.any?
      user_owns_mapping = @variant_mapping.order_items.any? do |oi|
        oi.order.organization_id == current_user.organization_id
      end
    end

    unless user_owns_mapping
      render json: { error: "Variant mapping not found" }, status: :not_found
      nil
    end

  rescue ActiveRecord::RecordNotFound
    render json: { error: "Variant mapping not found" }, status: :not_found
  end

  def variant_mapping_params
    params.require(:variant_mapping).permit(
      :product_variant_id,
      :bundle_id,
      :slot_position,
      :frame_sku_id,
      :frame_sku_code,
      :frame_sku_title,
      :frame_sku_cost_cents,
      :preview_url,
      :frame_sku_description,
      :frame_sku_long,
      :frame_sku_short,
      :frame_sku_unit,
      :width,
      :height,
      :unit,
      :country_code,
      :colour
    )
  end

  def image_params
    params.require(:variant_mapping).permit(
      :image_id,
      :image_key,
      :cx,
      :cy,
      :cw,
      :ch,
      :cloudinary_id,
      :image_width,
      :image_height,
      :image_filename
    )
  end

  # Find or create an Image record from the provided image parameters
  def find_or_create_image
    img_params = image_params

    # If no image params provided, return nil (variant mapping without image)
    return nil unless img_params[:image_key].present? &&
                     img_params[:cx].present? &&
                     img_params[:cy].present? &&
                     img_params[:cw].present? &&
                     img_params[:ch].present?

    # Rename image_id to external_image_id for the Image model
    external_id = img_params.delete(:image_id)
    img_params[:external_image_id] = external_id if external_id.present?

    # Always create a new Image record (as per user requirement)
    Image.create!(img_params)
  end

  # Copy the order item variant mapping to the product variant's default mapping
  def apply_to_default_variant_mapping(source_mapping)
    product_variant = source_mapping.product_variant
    country_code = source_mapping.country_code

    # Find or initialize the default variant mapping for this product variant and country
    default_mapping = product_variant.variant_mappings.find_or_initialize_by(
      country_code: country_code,
      is_default: true
    )

    # Create a copy of the image if present (as per user requirement, we always copy)
    new_image = nil
    if source_mapping.image.present?
      new_image = Image.create!(
        external_image_id: source_mapping.image.external_image_id,
        image_key: source_mapping.image.image_key,
        cloudinary_id: source_mapping.image.cloudinary_id,
        image_width: source_mapping.image.image_width,
        image_height: source_mapping.image.image_height,
        image_filename: source_mapping.image.image_filename,
        cx: source_mapping.image.cx,
        cy: source_mapping.image.cy,
        cw: source_mapping.image.cw,
        ch: source_mapping.image.ch
      )
    end

    # Copy all relevant fields from the source mapping
    default_mapping.assign_attributes(
      image: new_image,
      frame_sku_id: source_mapping.frame_sku_id,
      frame_sku_code: source_mapping.frame_sku_code,
      frame_sku_title: source_mapping.frame_sku_title,
      frame_sku_description: source_mapping.frame_sku_description,
      frame_sku_cost_cents: source_mapping.frame_sku_cost_cents,
      frame_sku_long: source_mapping.frame_sku_long,
      frame_sku_short: source_mapping.frame_sku_short,
      frame_sku_unit: source_mapping.frame_sku_unit,
      width: source_mapping.width,
      height: source_mapping.height,
      unit: source_mapping.unit,
      colour: source_mapping.colour,
      preview_url: source_mapping.preview_url,
      is_default: true
    )

    # Save the default mapping
    default_mapping.save!

    Rails.logger.info "Applied order item variant mapping #{source_mapping.id} to default variant mapping #{default_mapping.id} for product variant #{product_variant.id}"
  rescue => e
    Rails.logger.error "Failed to apply variant mapping to default: #{e.message}"
    # Don't fail the main operation if this fails
  end
end
