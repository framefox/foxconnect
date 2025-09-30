class VariantMappingsController < ApplicationController
  before_action :set_product_variant, only: [ :create ]
  before_action :set_variant_mapping, only: [ :destroy, :sync_to_shopify ]

  def create
    # Check if this is for a specific order item or for the product variant itself
    order_item_id = params[:order_item_id]

    if order_item_id.present?
      # Create a variant mapping specifically for this order item
      @order_item = OrderItem.find(order_item_id)
      @variant_mapping = VariantMapping.new(variant_mapping_params)

      if @variant_mapping.save
        # Associate this variant mapping only with the specific order item
        @order_item.update!(variant_mapping: @variant_mapping)

        variant_mapping_json = @variant_mapping.as_json(
          only: [
            :id, :image_id, :image_key, :frame_sku_id, :frame_sku_code,
            :frame_sku_title, :frame_sku_cost_cents, :cx, :cy, :cw, :ch, :preview_url, :cloudinary_id,
            :image_width, :image_height
          ],
          methods: [
            :artwork_preview_thumbnail, :artwork_preview_medium, :artwork_preview_large,
            :framed_preview_thumbnail, :framed_preview_medium, :framed_preview_large,
            :frame_sku_cost_formatted, :frame_sku_cost_dollars
          ]
        )

        render json: variant_mapping_json, status: :created
      else
        render json: { errors: @variant_mapping.errors.full_messages }, status: :unprocessable_entity
      end
    else
      # Create/update variant mapping for the product variant (existing behavior)
      @variant_mapping = @product_variant.default_variant_mapping || @product_variant.variant_mappings.build

      if @variant_mapping.update(variant_mapping_params)
        variant_mapping_json = @variant_mapping.as_json(
          only: [
            :id, :image_id, :image_key, :frame_sku_id, :frame_sku_code,
            :frame_sku_title, :frame_sku_cost_cents, :cx, :cy, :cw, :ch, :preview_url, :cloudinary_id,
            :image_width, :image_height
          ],
          methods: [
            :artwork_preview_thumbnail, :artwork_preview_medium, :artwork_preview_large,
            :framed_preview_thumbnail, :framed_preview_medium, :framed_preview_large,
            :frame_sku_cost_formatted, :frame_sku_cost_dollars
          ]
        )

        render json: variant_mapping_json, status: @variant_mapping.previously_new_record? ? :created : :ok
      else
        render json: { errors: @variant_mapping.errors.full_messages }, status: :unprocessable_entity
      end
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
    @product_variant = ProductVariant.find(params[:variant_mapping][:product_variant_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Product variant not found" }, status: :not_found
  end

  def set_variant_mapping
    @variant_mapping = VariantMapping.find(params[:id])
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
      :image_height
    )
  end
end
