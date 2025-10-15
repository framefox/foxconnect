class Admin::StoresController < Admin::ApplicationController
  before_action :set_store, only: [ :show, :edit, :update, :destroy, :sync_products ]

  def index
    @stores = Store.order(created_at: :desc)
    @users = User.order(:email)
  end

  def show
    # Load products data for the shared view
    @products = @store.products.includes(:product_variants).order(created_at: :desc)
    @products_count = @store.products.count
    @variants_count = @store.product_variants.count
    @last_sync = @store.last_sync_at

    render template: "stores/show"
  end

  def edit
    @users = User.order(:email)
  end

  def update
    if @store.update(store_params)
      redirect_to admin_stores_path, notice: "Store updated successfully."
    else
      @users = User.order(:email)
      render :edit, status: :unprocessable_entity
    end
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

  def store_params
    params.require(:store).permit(:user_id)
  end
end
