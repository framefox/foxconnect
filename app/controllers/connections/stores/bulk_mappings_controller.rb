class Connections::Stores::BulkMappingsController < Connections::ApplicationController
  before_action :set_store

  def index
    # Get unique variant titles with counts, sorted by most common first
    @variant_titles = @store.product_variants
      .select("product_variants.title, COUNT(*) as variant_count")
      .group("product_variants.title")
      .order("variant_count DESC, product_variants.title")

    # Also get counts of already mapped variants for each title
    @mapped_counts = @store.product_variants
      .joins(:variant_mappings)
      .where(variant_mappings: { is_default: true, country_code: current_user.country })
      .select("product_variants.title, COUNT(DISTINCT product_variants.id) as mapped_count")
      .group("product_variants.title")
      .index_by(&:title)
  end

  def create
    variant_title = params[:variant_title]
    frame_sku_params = params.require(:frame_sku).permit(
      :id, :code, :title, :description, :cost_cents, :preview_image,
      :long, :short, :unit, :colour, :country
    )

    # Find all variants with this title to get the count
    total_count = @store.product_variants.where(title: variant_title).count

    if total_count == 0
      render json: { success: false, error: "No variants found with title: #{variant_title}" }, status: :not_found
      return
    end

    # Create a tracking record
    bulk_mapping_request = BulkMappingRequest.create!(
      store: @store,
      variant_title: variant_title,
      frame_sku_title: frame_sku_params[:title],
      total_count: total_count,
      status: :pending
    )

    # Queue the background job with the request ID
    BulkMappingJob.perform_later(
      bulk_mapping_request_id: bulk_mapping_request.id,
      frame_sku_params: frame_sku_params.to_h,
      country_code: current_user.country
    )

    render json: {
      success: true,
      total_count: total_count,
      redirect_url: confirmation_connections_store_bulk_mappings_path(@store, request_id: bulk_mapping_request.id)
    }
  rescue ActionController::ParameterMissing => e
    render json: { success: false, error: e.message }, status: :bad_request
  rescue => e
    Rails.logger.error "Bulk mapping error: #{e.message}"
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def confirmation
    @bulk_mapping_request = @store.bulk_mapping_requests.find_by(id: params[:request_id])

    unless @bulk_mapping_request
      redirect_to connections_store_bulk_mappings_path(@store), alert: "Bulk mapping request not found."
      nil
    end
  end

  def status
    bulk_mapping_request = @store.bulk_mapping_requests.find_by(id: params[:request_id])

    unless bulk_mapping_request
      render json: { error: "Request not found" }, status: :not_found
      return
    end

    render json: {
      status: bulk_mapping_request.status,
      created_count: bulk_mapping_request.created_count,
      skipped_count: bulk_mapping_request.skipped_count,
      total_count: bulk_mapping_request.total_count,
      errors: bulk_mapping_request.error_messages || []
    }
  end

  private

  def set_store
    @store = Store.find_by!(uid: params[:store_uid])
  end
end
