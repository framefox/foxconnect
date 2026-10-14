class Connections::Stores::BulkMappingsController < Connections::ApplicationController
  before_action :set_store

  def index
    # Get unique variant titles with counts, sorted by most common first
    @variant_titles = @store.product_variants.present_in_source
      .select("product_variants.title, COUNT(*) as variant_count")
      .group("product_variants.title")
      .order("variant_count DESC, product_variants.title")

    # Also get counts of already mapped variants for each title
    @mapped_counts = @store.product_variants.present_in_source
      .joins(:variant_mappings)
      .where(variant_mappings: { is_default: true, country_code: current_user.country })
      .select("product_variants.title, COUNT(DISTINCT product_variants.id) as mapped_count")
      .group("product_variants.title")
      .index_by(&:title)
  end

  def create
    variant_title = params[:variant_title]
    reuse_existing = ActiveModel::Type::Boolean.new.cast(params[:reuse_existing])
    frame_sku_params = if reuse_existing
      ExistingBulkMappingService.call(store: @store, variant_title: variant_title, country_code: current_user.country).with_indifferent_access
    else
      params.require(:frame_sku).permit(
        :id, :code, :title, :description, :cost_cents, :preview_image,
        :long, :short, :unit, :colour, :country
      )
    end

    # Find all variants with this title to get the count
    total_count = @store.product_variants.present_in_source.where(title: variant_title).count

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
      country_code: current_user.country,
      overwrite: !reuse_existing && (params[:overwrite] == true || params[:overwrite] == "true")
    )

    render json: {
      success: true,
      total_count: total_count,
      redirect_url: confirmation_connections_store_bulk_mappings_path(@store, request_id: bulk_mapping_request.id)
    }
  rescue ExistingBulkMappingService::Unavailable => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing => e
    render json: { success: false, error: e.message }, status: :bad_request
  rescue => e
    Rails.logger.error "Bulk mapping error: #{e.message}"
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def map_remaining_all
    titles = params[:variant_titles]
    unless titles.is_a?(Array) && titles.all? { |title| title.is_a?(String) }
      render json: { error: "Please provide the variant titles to map." }, status: :bad_request
      return
    end

    # Recheck the confirmed list against current store/country data. Never expand
    # the operation to titles that appeared after the confirmation was opened.
    variants = @store.product_variants.present_in_source.where(title: titles.uniq)
    totals = variants.group(:title).count
    mapped = variants.joins(:variant_mappings)
      .where(variant_mappings: { is_default: true, country_code: current_user.country })
      .group(:title).distinct.count(:id)
    queued = []
    skipped = []

    titles.uniq.each do |title|
      if mapped.fetch(title, 0).zero? || mapped.fetch(title, 0) >= totals.fetch(title, 0)
        skipped << { title: title, error: "This title is no longer partially mapped. Refresh the list to see its current status." }
        next
      end

      begin
        sku = ExistingBulkMappingService.call(store: @store, variant_title: title, country_code: current_user.country)
        request = @store.bulk_mapping_requests.create!(
          variant_title: title, frame_sku_title: sku.fetch("title"),
          total_count: totals.fetch(title), status: :pending
        )
        BulkMappingJob.perform_later(
          bulk_mapping_request_id: request.id, frame_sku_params: sku,
          country_code: current_user.country, overwrite: false
        )
        queued << { title: title, redirect_url: confirmation_connections_store_bulk_mappings_path(@store, request_id: request.id) }
      rescue ExistingBulkMappingService::Unavailable => e
        skipped << { title: title, error: e.message }
      end
    end

    render json: { queued: queued, skipped: skipped }
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
    @store = current_user.stores.find_by!(uid: params[:store_uid])
  end
end
