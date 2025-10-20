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

  private

  def custom_print_size_params
    params.require(:custom_print_size).permit(:long, :short, :unit, :frame_sku_size_id, :frame_sku_size_description)
  end
end
