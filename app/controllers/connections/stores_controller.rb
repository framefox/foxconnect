class Connections::StoresController < Connections::ApplicationController
  before_action :set_store, only: [ :show, :destroy, :sync_products, :toggle_active, :settings, :update_fulfill_new_products ]

  def show
    # Load products data for the shared view
    @products = @store.products.includes(:product_variants)

    # Apply search filter if present (case-insensitive)
    if params[:search].present?
      search_term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%"
      @products = @products.where("title ILIKE ?", search_term)
    end

    @products = @products.order(created_at: :desc)
    @products_count = @store.products.count
    @variants_count = @store.product_variants.count
    @last_sync = @store.last_sync_at

    render template: "stores/show"
  end

  def destroy
    @store.destroy
    redirect_to connections_root_path, notice: "Store connection removed successfully."
  end

  def sync_products
    @store.sync_products!
    redirect_to connections_store_path(@store), notice: "Product sync initiated for #{@store.name}."
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

  private

  def fulfill_new_products_params
    params.require(:store).permit(:fulfill_new_products)
  end

  def set_store
    @store = current_user.stores.find(params[:id])
  end
end
