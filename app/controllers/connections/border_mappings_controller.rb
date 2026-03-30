class Connections::BorderMappingsController < Connections::ApplicationController
  before_action :set_store
  before_action :set_border_mapping, only: [ :destroy ]

  def index
    @border_mappings = @store.border_mappings.order(:created_at)
  end

  def create
    @border_mapping = @store.border_mappings.new(border_mapping_params)

    if @border_mapping.save
      render json: @border_mapping.as_json(only: [ :id, :paper_type_id, :paper_type_name, :border_width_mm ]), status: :created
    else
      render json: { errors: @border_mapping.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @border_mapping.destroy
    render json: { message: "Border mapping removed" }, status: :ok
  end

  private

  def set_store
    @store = current_user.stores.find_by!(uid: params[:store_uid])
  end

  def set_border_mapping
    @border_mapping = @store.border_mappings.find(params[:id])
  end

  def border_mapping_params
    params.require(:border_mapping).permit(:paper_type_id, :paper_type_name, :border_width_mm)
  end
end
