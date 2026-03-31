class Admin::StoresController < Admin::ApplicationController
  before_action :set_store, only: [ :show, :edit, :update, :destroy, :sync_products, :test_api_connection, :request_reauthentication, :soft_delete, :restore ]

  def index
    @status_filter = params[:status].presence || "default"
    @stores = apply_status_filter(Store.order(created_at: :desc))
    @users = User.order(:email)
    @stores_needing_scopes = stores_missing_required_scopes

    @counts = {
      default: Store.not_deleted.count,
      active: Store.not_deleted.active.count,
      inactive: Store.not_deleted.inactive.count,
      deleted: Store.soft_deleted.count
    }
  end

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

  def soft_delete
    @store.soft_delete!
    redirect_to admin_stores_path, notice: "#{@store.name} has been soft deleted and deactivated."
  end

  def restore
    @store.restore!
    redirect_to admin_stores_path, notice: "#{@store.name} has been restored."
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

  def include_archived?
    params[:include_archived] == "true"
  end

  def set_store
    @store = Store.find_by!(uid: params[:uid])
  end

  def store_params
    params.require(:store).permit(:name, :user_id, :mockup_bg_colour, :order_import_paused)
  end

  def apply_status_filter(scope)
    case @status_filter
    when "active"
      scope.not_deleted.active
    when "inactive"
      scope.not_deleted.inactive
    when "deleted"
      scope.soft_deleted
    else
      scope.not_deleted
    end
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
