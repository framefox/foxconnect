class Admin::StoresController < Admin::ApplicationController
  before_action :set_store, only: [ :show, :edit, :update, :destroy, :sync_products, :test_api_connection, :request_reauthentication ]

  def index
    @stores = Store.order(created_at: :desc)
    @users = User.order(:email)
    @stores_needing_scopes = stores_missing_required_scopes
  end

  def show
    # Load store data for admin view
    products = @store.products.includes(:product_variants)

    # Apply search filter if present (case-insensitive)
    if params[:search].present?
      search_term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%"
      products = products.where("title ILIKE ?", search_term)
    end

    products = products.order(created_at: :desc)

    # Paginate products (50 per page for grid layout)
    @pagy, @products = pagy(products, limit: 50)

    @products_count = @store.products.count
    @variants_count = @store.product_variants.count
    @last_sync = @store.last_sync_at
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

  def test_api_connection
    service = StoreApiConnectionTestService.new(@store)
    result = service.test_connection

    if result[:success]
      flash[:notice] = "✅ #{result[:message]}"
    else
      message = "❌ #{result[:message]}"
      message += " - #{result[:suggestion]}" if result[:suggestion]
      flash[:alert] = message
    end

    redirect_to admin_store_path(@store)
  end

  # Flag a single store for reauthentication
  def request_reauthentication
    @store.update!(
      needs_reauthentication: true,
      reauthentication_flagged_at: Time.current
    )

    flash[:notice] = "#{@store.name} has been flagged for reauthentication. The user will be prompted to reconnect."
    redirect_to admin_stores_path
  end

  # Flag all stores missing required scopes for reauthentication
  def flag_stores_missing_scopes
    stores = stores_missing_required_scopes
    count = 0

    stores.each do |store|
      unless store.needs_reauthentication?
        store.update!(
          needs_reauthentication: true,
          reauthentication_flagged_at: Time.current
        )
        count += 1
      end
    end

    if count > 0
      flash[:notice] = "#{count} store(s) have been flagged for reauthentication due to missing scopes."
    else
      flash[:notice] = "No stores needed to be flagged - all are up to date or already flagged."
    end

    redirect_to admin_stores_path
  end

  private

  def set_store
    @store = Store.find_by!(uid: params[:uid])
  end

  def store_params
    params.require(:store).permit(:name, :user_id, :ai_mapping_enabled, :ai_mapping_prompt, :mockup_bg_colour, :order_import_paused)
  end

  # Find stores that are missing required scopes
  def stores_missing_required_scopes
    required_scopes = ShopifyApp.configuration.scope.split(",").map(&:strip).sort

    Store.shopify_stores.active.select do |store|
      next false unless store.access_scopes.present?

      store_scopes = store.access_scopes.split(",").map(&:strip).sort
      missing_scopes = required_scopes - store_scopes
      missing_scopes.any?
    end
  end
end
