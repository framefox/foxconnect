class SavedItemsController < ApplicationController
  before_action :authenticate_user!

  # GET /saved_items.json
  def index
    # Get the user's saved items with custom print size info
    saved_items = current_user.saved_items.includes(:custom_print_size).recent_first

    render json: {
      saved_frame_sku_ids: saved_items.pluck(:frame_sku_id),
      saved_items: saved_items.map { |item|
        {
          frame_sku_id: item.frame_sku_id,
          custom_print_size_id: item.custom_print_size_id,
          custom_print_size: item.custom_print_size ? {
            id: item.custom_print_size.id,
            long: item.custom_print_size.long,
            short: item.custom_print_size.short,
            unit: item.custom_print_size.unit,
            frame_sku_size_id: item.custom_print_size.frame_sku_size_id,
            frame_sku_size_description: item.custom_print_size.frame_sku_size_description,
            dimensions_display: item.custom_print_size.dimensions_display,
            full_description: item.custom_print_size.full_description
          } : nil
        }
      }
    }
  end

  # POST /saved_items.json
  def create
    @saved_item = current_user.saved_items.build(saved_item_params)

    if @saved_item.save
      render json: { 
        success: true,
        frame_sku_id: @saved_item.frame_sku_id 
      }, status: :created
    else
      render json: { 
        success: false,
        errors: @saved_item.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # DELETE /saved_items/:id.json
  def destroy
    # Find by frame_sku_id instead of id
    frame_sku_id = params[:id].to_i
    @saved_item = current_user.saved_items.find_by(frame_sku_id: frame_sku_id)

    if @saved_item
      @saved_item.destroy
      render json: { 
        success: true,
        frame_sku_id: frame_sku_id 
      }, status: :ok
    else
      render json: { 
        success: false,
        error: "Saved item not found" 
      }, status: :not_found
    end
  end

  private

  def saved_item_params
    params.require(:saved_item).permit(:frame_sku_id, :custom_print_size_id)
  end
end

