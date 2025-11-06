class Admin::Stores::ProductsController < Admin::ApplicationController
  before_action :set_store
  before_action :set_shopify_product, only: [:duplicate, :create_duplicate]

  def new
    # Render the new product form
  end

  def create
    service = ShopifyProductCreateService.new(@store)
    result = service.create_product(product_params)

    if result[:success]
      redirect_to admin_store_path(@store), notice: "Product '#{product_params[:title]}' created successfully in Shopify!"
    else
      flash.now[:alert] = "Failed to create product: #{result[:errors].join(', ')}"
      render :new, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Error creating Shopify product: #{e.message}"
    flash.now[:alert] = "An error occurred: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def duplicate
    # @shopify_product is already set by before_action
    # Render the duplicate form
  end

  def create_duplicate
    # Build product data with options from original product
    product_data = {
      title: duplicate_params[:title],
      description_html: duplicate_params[:description_html],
      product_options: @shopify_product[:product_options]
    }

    service = ShopifyProductCreateService.new(@store)
    result = service.create_product(product_data)

    if result[:success]
      redirect_to admin_store_path(@store), notice: "Product '#{duplicate_params[:title]}' duplicated successfully in Shopify!"
    else
      flash.now[:alert] = "Failed to duplicate product: #{result[:errors].join(', ')}"
      render :duplicate, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Error duplicating Shopify product: #{e.message}"
    flash.now[:alert] = "An error occurred: #{e.message}"
    render :duplicate, status: :unprocessable_entity
  end

  private

  def set_store
    @store = Store.find_by!(uid: params[:store_uid])
    
    # Ensure store is Shopify
    unless @store.shopify?
      redirect_to admin_store_path(@store), alert: "Product creation is only available for Shopify stores."
    end
    
    # Ensure store is active
    unless @store.active?
      redirect_to admin_store_path(@store), alert: "Cannot create products for inactive stores."
    end
  end

  def set_shopify_product
    service = ShopifyProductCreateService.new(@store)
    result = service.fetch_product(params[:id])
    
    if result[:success]
      @shopify_product = result[:product]
    else
      redirect_to admin_store_path(@store), alert: "Failed to fetch product: #{result[:errors].join(', ')}"
    end
  end

  def product_params
    params.require(:product).permit(
      :title,
      :description_html,
      product_options: [:name, values: []]
    )
  end

  def duplicate_params
    params.require(:product).permit(:title, :description_html)
  end
end

