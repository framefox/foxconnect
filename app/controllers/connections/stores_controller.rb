class Connections::StoresController < Connections::ApplicationController
  before_action :set_store, only: [ :show, :destroy, :sync_products, :toggle_active ]
  
  def index
    @stores = Store.order(created_at: :desc)
    @stores_by_platform = @stores.group_by(&:platform)
  end
  
  def show
    @recent_syncs = [] # TODO: Implement sync history in Phase 2
    @order_stats = {} # TODO: Implement order statistics in Phase 3
  end
  
  def destroy
    @store.destroy
    redirect_to connections_stores_path, notice: "Store connection removed successfully."
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
