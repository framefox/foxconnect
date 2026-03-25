class Connections::StoresController < Connections::ApplicationController
  before_action :set_store, only: [ :show, :destroy, :sync_products, :check_products, :toggle_active, :settings, :update_fulfill_new_products, :update_settings ]

  def show
    products = @store.products.includes(:product_variants)
    products = products.present_in_source unless include_archived?

    # Apply search filter if present (case-insensitive)
    # Searches both product titles and variant titles
    if params[:search].present?
      search_term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%"
      matching_scope = @store.products
      matching_scope = matching_scope.present_in_source unless include_archived?
      variant_scope = @store.product_variants
      variant_scope = variant_scope.present_in_source unless include_archived?

      title_matches = matching_scope.where("products.title ILIKE ?", search_term).select(:id)
      variant_matches = variant_scope.where("product_variants.title ILIKE ?", search_term).select(:product_id)

      products = products.where(id: title_matches).or(products.where(id: variant_matches))
    end

    products = products.order(created_at: :desc)

    # Paginate products (50 per page for grid layout)
    @pagy, @products = pagy(products, limit: 50)

    @include_archived = include_archived?
    @archived_products_count = @store.products.removed_from_source.count
    @archived_variants_count = @store.product_variants.removed_from_source.count
    @products_count = @include_archived ? @store.products.count : @store.products.present_in_source.count
    @variants_count = @include_archived ? @store.product_variants.count : @store.product_variants.present_in_source.count
    @last_sync = @store.last_sync_at

    render template: "stores/show"
  end

  def destroy
    @store.destroy
    redirect_to connections_root_path, notice: "Store connection removed successfully."
  end

  def sync_products
    @store.sync_products!
    redirect_to connections_store_path(@store, from_sync: true), notice: "Product sync initiated for #{@store.name}."
  end

  def check_products
    # Return JSON with current product count
    product_count = @store.products.present_in_source.count
    render json: { products_count: product_count }
  end

  def toggle_active
    @store.update!(active: !@store.active?)
    status = @store.active? ? "activated" : "deactivated"
    redirect_to connections_store_path(@store), notice: "Store connection #{status}."
  end

  def settings
    # Settings page - placeholder for future configuration options
  end

  def update_fulfill_new_products
    if @store.update(fulfill_new_products_params)
      redirect_to settings_connections_store_path(@store), notice: "Fulfillment settings updated successfully."
    else
      redirect_to settings_connections_store_path(@store), alert: "Failed to update settings."
    end
  end

  def update_settings
    if @store.update(settings_params)
      redirect_to settings_connections_store_path(@store), notice: "Settings updated successfully."
    else
      redirect_to settings_connections_store_path(@store), alert: "Failed to update settings."
    end
  end

  private

  def include_archived?
    params[:include_archived] == "true"
  end

  def fulfill_new_products_params
    params.require(:store).permit(:fulfill_new_products)
  end

  def settings_params
    params.require(:store).permit(:mockup_bg_colour)
  end

  def set_store
    @store = current_user.stores.find_by!(uid: params[:uid])
  end
end
