class Connections::StoresController < Connections::ApplicationController
  before_action :set_store, only: [ :show, :destroy, :sync_products, :check_products, :toggle_active, :settings, :update_fulfill_new_products, :update_settings, :enable_search_fulfilment, :disable_search_fulfilment ]

  def show
    products = filtered_products.order(created_at: :desc)

    # Paginate products (50 per page for grid layout)
    @pagy, @products = pagy(products, limit: 50)
    Product.preload_variant_counts(@products)

    @include_archived = include_archived?
    counts = @store.catalog_counts(include_archived: @include_archived)
    @archived_products_count = counts[:archived_products_count]
    @archived_variants_count = counts[:archived_variants_count]
    @products_count = counts[:products_count]
    @variants_count = counts[:variants_count]
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

  def enable_search_fulfilment
    update_search_fulfilment(true)
  end

  def disable_search_fulfilment
    update_search_fulfilment(false)
  end

  private

  def update_search_fulfilment(active)
    if params[:search].blank?
      redirect_to connections_store_path(@store), alert: "Search for products before changing fulfilment."
      return
    end

    products = filtered_products
    product_ids = products.select(:id)
    variant_count = ProductVariant.present_in_source.where(product_id: product_ids).update_all(fulfilment_active: active)
    product_count = products.update_all(fulfilment_active: active)
    verb = active ? "enabled" : "disabled"

    redirect_to connections_store_path(@store, search: params[:search], include_archived: (include_archived? ? "true" : nil)),
      notice: "Fulfilment #{verb} for #{product_count} #{'product'.pluralize(product_count)} and #{variant_count} #{'variant'.pluralize(variant_count)} matching \"#{params[:search]}\"."
  end

  def filtered_products
    products = @store.products
    products = products.present_in_source unless include_archived?
    return products if params[:search].blank?

    search_term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%"
    matching_scope = @store.products
    matching_scope = matching_scope.present_in_source unless include_archived?
    variant_scope = @store.product_variants
    variant_scope = variant_scope.present_in_source unless include_archived?

    title_matches = matching_scope.where("products.title ILIKE ?", search_term).select(:id)
    variant_matches = variant_scope.where("product_variants.title ILIKE ?", search_term).select(:product_id)

    products.where(id: title_matches).or(products.where(id: variant_matches))
  end

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
