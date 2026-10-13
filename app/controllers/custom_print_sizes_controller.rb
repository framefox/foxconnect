class CustomPrintSizesController < ApplicationController
  before_action :authenticate_user!

  # GET /custom_print_sizes.json
  def index
    @custom_print_sizes = current_user.custom_print_sizes.recent_first

    render json: @custom_print_sizes.map { |custom_size|
      {
        id: custom_size.id,
        long: custom_size.long,
        short: custom_size.short,
        unit: custom_size.unit,
        material_type: custom_size.material_type,
        frame_sku_size_id: custom_size.frame_sku_size_id,
        frame_sku_size_description: custom_size.frame_sku_size_description,
        dimensions_display: custom_size.dimensions_display,
        full_description: custom_size.full_description,
        created_at: custom_size.created_at
      }
    }
  end

  # POST /custom_print_sizes.json
  def create
    @custom_print_size = current_user.custom_print_sizes.build(custom_print_size_params)

    if @custom_print_size.save
      render json: {
        id: @custom_print_size.id,
        long: @custom_print_size.long,
        short: @custom_print_size.short,
        unit: @custom_print_size.unit,
        material_type: @custom_print_size.material_type,
        frame_sku_size_id: @custom_print_size.frame_sku_size_id,
        frame_sku_size_description: @custom_print_size.frame_sku_size_description,
        dimensions_display: @custom_print_size.dimensions_display,
        full_description: @custom_print_size.full_description,
        created_at: @custom_print_size.created_at
      }, status: :created
    else
      render json: { errors: @custom_print_size.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    custom_size = current_user.custom_print_sizes.find(params[:id])
    attributes = custom_print_size_params
    unless attributes[:material_type].in?(%w[paper canvas])
      render json: { errors: ["Please select Paper or Canvas"] }, status: :unprocessable_entity
      return
    end

    custom_size.with_lock do
      custom_size.assign_attributes(attributes)
      if custom_size.valid?
        # Saved entries pair a specific SKU with these dimensions and material.
        # Clear stale pairs atomically when the definition changes.
        custom_size.saved_items.destroy_all if custom_size.changed?
        custom_size.save!
        render json: custom_size.as_json.merge(
          dimensions_display: custom_size.dimensions_display,
          full_description: custom_size.full_description
        )
      else
        render json: { errors: custom_size.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  def destroy
    custom_size = current_user.custom_print_sizes.find(params[:id])
    custom_size.with_lock { custom_size.destroy! }
    head :no_content
  end

  private

  def custom_print_size_params
    params.require(:custom_print_size).permit(:long, :short, :unit, :material_type, :frame_sku_size_id, :frame_sku_size_description)
  end
end
