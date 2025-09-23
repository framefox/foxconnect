class Connections::Shopify::AuthController < Connections::ApplicationController
  include ShopifyApp::LoginProtection
  
  def connect
    # Redirect to Shopify OAuth - this will use the ShopifyApp engine
    redirect_to "/login"
  end
  
  def callback
    # This will be handled by the ShopifyApp engine
    # After successful auth, user will be redirected to root_url (/connections)
    redirect_to connections_root_path
  end
  
  def disconnect
    store = Store.find(params[:id])
    if store
      store.destroy
      flash[:notice] = "Successfully disconnected #{store.name} from Framefox Connect."
    else
      flash[:alert] = "Store not found."
    end
    
    redirect_to connections_root_path
  end
end
