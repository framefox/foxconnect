class Connections::StoresController < Connections::ApplicationController
  before_action :set_store, only: [ :show, :destroy, :sync_products, :toggle_active ]

  def show
    # Load products data (previously in products#index)
    @products = @store.products.includes(:product_variants).order(created_at: :desc)
    @products_count = @store.products.count
    @variants_count = @store.product_variants.count
    @last_sync = @store.last_sync_at
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

  private

  def set_store
    @store = Store.find(params[:id])
  end
end
