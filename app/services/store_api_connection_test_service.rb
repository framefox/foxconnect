# Service for testing API connections to e-commerce platforms
#
# Usage:
#   service = StoreApiConnectionTestService.new(store)
#   result = service.test_connection
#   
#   if result[:success]
#     puts result[:message]
#     puts result[:shop_data] # Contains shop info if successful
#   else
#     puts result[:message]
#     puts result[:suggestion] # Optional suggestion for fixing the issue
#   end
#
class StoreApiConnectionTestService
  attr_reader :store

  def initialize(store)
    @store = store
  end

  def test_connection
    case store.platform
    when "shopify"
      test_shopify_connection
    when "squarespace"
      test_squarespace_connection
    when "wix"
      test_wix_connection
    else
      {
        success: false,
        message: "API connection test not implemented for #{store.platform} stores"
      }
    end
  end

  private

  def test_shopify_connection
    unless store.shopify_token.present?
      return {
        success: false,
        message: "No Shopify token found for this store"
      }
    end

    begin
      session = store.shopify_session
      client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

      query = <<~GRAPHQL
        query {
          shop {
            name
            myshopifyDomain
            plan {
              displayName
            }
          }
        }
      GRAPHQL

      response = client.query(query: query)

      if response.body.dig("data", "shop")
        shop_data = response.body["data"]["shop"]
        {
          success: true,
          message: "API Connection Successful! Connected to: #{shop_data['name']} (#{shop_data['myshopifyDomain']})",
          shop_data: shop_data
        }
      elsif response.body["errors"]
        error_msg = extract_error_message(response.body["errors"])
        {
          success: false,
          message: "API Connection Failed: #{error_msg}",
          suggestion: auth_error?(error_msg) ? "Consider marking this store as inactive." : nil
        }
      else
        {
          success: false,
          message: "API Connection Failed: Unknown error"
        }
      end
    rescue ShopifyAPI::Errors::HttpResponseError => e
      {
        success: false,
        message: "API Connection Failed: #{e.message}",
        suggestion: auth_error?(e.message) ? "Consider marking this store as inactive." : nil
      }
    rescue => e
      {
        success: false,
        message: "API Connection Failed: #{e.message}"
      }
    end
  end

  def test_squarespace_connection
    # TODO: Implement Squarespace connection test
    {
      success: false,
      message: "API connection test not yet implemented for Squarespace stores"
    }
  end

  def test_wix_connection
    # TODO: Implement Wix connection test
    {
      success: false,
      message: "API connection test not yet implemented for Wix stores"
    }
  end

  def extract_error_message(errors)
    if errors.is_a?(Array)
      errors.first["message"] rescue errors.inspect
    elsif errors.is_a?(Hash)
      errors["message"] || errors.to_s
    else
      errors.to_s
    end
  end

  def auth_error?(message)
    message.to_s.downcase.match?(/invalid|unauthorized|token|access/)
  end
end

