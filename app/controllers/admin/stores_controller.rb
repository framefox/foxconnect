class Admin::StoresController < Admin::ApplicationController
  before_action :set_store, only: [ :show, :destroy, :sync_products ]

  def index
    @stores = Store.order(created_at: :desc)
  end

  def show
    # Store details will be shown here
  end

  def destroy
    @store.destroy
    redirect_to admin_stores_path, notice: "Store connection removed successfully."
  end

  def sync_products
    @store.sync_products!
    redirect_to admin_store_path(@store), notice: "Product sync initiated."
  end

  private

  def set_store
    @store = Store.find(params[:id])
  end
end
