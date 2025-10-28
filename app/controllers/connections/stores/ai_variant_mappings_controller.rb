class Connections::Stores::AiVariantMappingsController < Connections::ApplicationController
  before_action :set_store
  before_action :set_product

  def suggest
    # Find a reference mapping for the user's country
    reference_mapping = VariantMapping
                          .joins(:product_variant)
                          .where(product_variants: { product_id: @product.id })
                          .where(country_code: current_user.country, is_default: true)
                          .first

    if reference_mapping.blank?
      render json: {
        success: false,
        error: "Please create at least one variant mapping for #{current_user.country_name} before using AI auto-mapping."
      }, status: :unprocessable_entity
      return
    end

    # Call the AI service
    result = AiVariantMatchingService.new(
      product: @product,
      reference_mapping: reference_mapping,
      user: current_user,
      store: @store
    ).call

    if result[:success]
      render json: result, status: :ok
    else
      render json: result, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "AI suggest mappings error: #{e.message}"
    render json: {
      success: false,
      error: "An error occurred while generating suggestions: #{e.message}"
    }, status: :internal_server_error
  end

  def create
    suggestions = params[:suggestions] || []

    if suggestions.empty?
      render json: {
        success: false,
        error: "No suggestions provided"
      }, status: :unprocessable_entity
      return
    end

    # Find the reference mapping to copy image fields from
    reference_mapping = VariantMapping
                          .joins(:product_variant)
                          .where(product_variants: { product_id: @product.id })
                          .where(country_code: current_user.country, is_default: true)
                          .first

    if reference_mapping.blank?
      render json: {
        success: false,
        error: "Reference mapping not found"
      }, status: :unprocessable_entity
      return
    end

    created_mappings = []
    errors = []

    suggestions.each do |suggestion|
      variant_id = suggestion["variant_id"]
      frame_sku = suggestion["frame_sku"]

      variant = @product.product_variants.find_by(id: variant_id)
      unless variant
        errors << "Variant #{variant_id} not found"
        next
      end

      # Create a copy of the image from reference mapping (always copy, never share)
      new_image = nil
      if reference_mapping.image.present?
        new_image = Image.create!(
          external_image_id: reference_mapping.image.external_image_id,
          image_key: reference_mapping.image.image_key,
          cloudinary_id: reference_mapping.image.cloudinary_id,
          image_width: reference_mapping.image.image_width,
          image_height: reference_mapping.image.image_height,
          image_filename: reference_mapping.image.image_filename,
          cx: reference_mapping.image.cx,
          cy: reference_mapping.image.cy,
          cw: reference_mapping.image.cw,
          ch: reference_mapping.image.ch
        )
      end

      # Create the variant mapping
      mapping = variant.variant_mappings.new(
        # Associate with the copied image
        image: new_image,

        # Set frame SKU fields from the matched frame_sku
        frame_sku_id: frame_sku["id"],
        frame_sku_code: frame_sku["code"],
        frame_sku_title: frame_sku["title"],
        frame_sku_description: frame_sku["description"],
        frame_sku_cost_cents: frame_sku["cost_cents"],
        frame_sku_long: frame_sku["long"],
        frame_sku_short: frame_sku["short"],
        frame_sku_unit: frame_sku["unit"],
        preview_url: frame_sku["preview_image"],
        colour: frame_sku["colour"],

        # Set country and default flag
        country_code: current_user.country,
        is_default: true
      )

      if mapping.save
        created_mappings << mapping
      else
        errors << "Failed to create mapping for variant #{variant.title}: #{mapping.errors.full_messages.join(', ')}"
      end
    end

    if errors.empty?
      # Return the created mappings
      mappings_json = created_mappings.map do |mapping|
        mapping.as_json(
          only: [
            :id, :product_variant_id, :frame_sku_id, :frame_sku_code,
            :frame_sku_title, :frame_sku_cost_cents, :preview_url,
            :frame_sku_description, :frame_sku_long, :frame_sku_short,
            :frame_sku_unit, :width, :height, :unit, :colour, :country_code
          ],
          methods: [
            :image_id, :image_key, :cx, :cy, :cw, :ch, :cloudinary_id,
            :image_width, :image_height, :image_filename,
            :artwork_preview_thumbnail, :artwork_preview_medium, :artwork_preview_large,
            :framed_preview_thumbnail, :framed_preview_medium, :framed_preview_large,
            :frame_sku_cost_formatted, :frame_sku_cost_dollars, :dimensions_display
          ]
        )
      end

      render json: {
        success: true,
        created_count: created_mappings.count,
        mappings: mappings_json
      }, status: :created
    else
      render json: {
        success: false,
        created_count: created_mappings.count,
        errors: errors
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "AI create mappings error: #{e.message}"
    render json: {
      success: false,
      error: "An error occurred while creating mappings: #{e.message}"
    }, status: :internal_server_error
  end

  private

  def set_store
    @store = Store.find_by!(uid: params[:store_uid])
  end

  def set_product
    @product = @store.products.find(params[:product_id])
  end
end
