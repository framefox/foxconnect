class VariantMappingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_product_variant, only: [ :create ]
  before_action :set_variant_mapping, only: [ :update, :destroy, :sync_to_shopify ]

  def create
    # Check if this is for a specific order item or for the product variant itself
    order_item_id = params[:order_item_id]

    if order_item_id.present?
      # Create a variant mapping specifically for this order item
      @order_item = OrderItem.joins(order: :store)
                             .where(stores: { user_id: current_user.id })
                             .find(order_item_id)
      # Explicitly set is_default: false to prevent this order item mapping from becoming
      # the ProductVariant's default mapping
      @variant_mapping = VariantMapping.new(variant_mapping_params.merge(is_default: false))

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
            :id, :image_id, :image_key, :frame_sku_id, :frame_sku_code,
            :frame_sku_title, :frame_sku_cost_cents, :cx, :cy, :cw, :ch, :preview_url, :cloudinary_id,
            :image_width, :image_height, :frame_sku_description, :image_filename,
            :frame_sku_long, :frame_sku_short, :frame_sku_unit, :width, :height, :unit, :colour
          ],
          methods: [
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
      # Create/update variant mapping for the product variant (existing behavior)
      @variant_mapping = @product_variant.default_variant_mapping

      if @variant_mapping.present?
        # Update existing default mapping
        success = @variant_mapping.update(variant_mapping_params)
      else
        # Create new default mapping - explicitly set is_default: true
        @variant_mapping = @product_variant.variant_mappings.build(variant_mapping_params.merge(is_default: true))
        success = @variant_mapping.save
      end

      if success
        variant_mapping_json = @variant_mapping.as_json(
          only: [
            :id, :image_id, :image_key, :frame_sku_id, :frame_sku_code,
            :frame_sku_title, :frame_sku_cost_cents, :cx, :cy, :cw, :ch, :preview_url, :cloudinary_id,
            :image_width, :image_height, :frame_sku_description, :image_filename,
            :frame_sku_long, :frame_sku_short, :frame_sku_unit, :width, :height, :unit, :colour
          ],
          methods: [
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

    if @variant_mapping.update(variant_mapping_params)
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
          :id, :image_id, :image_key, :frame_sku_id, :frame_sku_code,
          :frame_sku_title, :frame_sku_cost_cents, :cx, :cy, :cw, :ch, :preview_url, :cloudinary_id,
          :image_width, :image_height, :frame_sku_description, :image_filename,
          :frame_sku_long, :frame_sku_short, :frame_sku_unit, :width, :height, :unit, :colour
        ],
        methods: [
          :artwork_preview_thumbnail, :artwork_preview_medium, :artwork_preview_large,
          :framed_preview_thumbnail, :framed_preview_medium, :framed_preview_large,
          :frame_sku_cost_formatted, :frame_sku_cost_dollars
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
    result = @variant_mapping.sync_to_shopify_variant(size: 1000)

    if result[:success]
      render json: {
        success: true,
        message: "Successfully synced image to Shopify variant",
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
    Rails.logger.error "Error syncing variant mapping to Shopify: #{e.message}"
    render json: {
      success: false,
      error: "Failed to sync image to Shopify: #{e.message}"
    }, status: :internal_server_error
  end

  private

  def set_product_variant
    # Ensure the product variant belongs to the user's stores
    @product_variant = ProductVariant.joins(product: :store)
                                     .where(stores: { user_id: current_user.id })
                                     .find(params[:variant_mapping][:product_variant_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Product variant not found" }, status: :not_found
  end

  def set_variant_mapping
    # Ensure the variant mapping belongs to the user's stores
    @variant_mapping = VariantMapping.joins(product_variant: { product: :store })
                                     .where(stores: { user_id: current_user.id })
                                     .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Variant mapping not found" }, status: :not_found
  end

  def variant_mapping_params
    params.require(:variant_mapping).permit(
      :product_variant_id,
      :image_id,
      :image_key,
      :frame_sku_id,
      :frame_sku_code,
      :frame_sku_title,
      :frame_sku_cost_cents,
      :cx,
      :cy,
      :cw,
      :ch,
      :preview_url,
      :cloudinary_id,
      :image_width,
      :image_height,
      :frame_sku_description,
      :image_filename,
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

  # Copy the order item variant mapping to the product variant's default mapping
  def apply_to_default_variant_mapping(source_mapping)
    product_variant = source_mapping.product_variant
    country_code = source_mapping.country_code

    # Find or initialize the default variant mapping for this product variant and country
    default_mapping = product_variant.variant_mappings.find_or_initialize_by(
      country_code: country_code,
      is_default: true
    )

    # Copy all relevant fields from the source mapping
    default_mapping.assign_attributes(
      image_id: source_mapping.image_id,
      image_key: source_mapping.image_key,
      image_filename: source_mapping.image_filename,
      cloudinary_id: source_mapping.cloudinary_id,
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
      cx: source_mapping.cx,
      cy: source_mapping.cy,
      cw: source_mapping.cw,
      ch: source_mapping.ch,
      image_width: source_mapping.image_width,
      image_height: source_mapping.image_height,
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
