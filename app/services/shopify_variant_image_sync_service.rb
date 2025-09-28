# Service for syncing variant images to Shopify using GraphQL API
#
# Usage Examples:
#
# # Basic usage - sync single variant image
# service = ShopifyVariantImageSyncService.new(store)
# result = service.sync_variant_image(
#   shopify_variant_id: 12345,
#   image_url: "https://example.com/image.jpg",
#   alt_text: "Custom variant image"
# )
#
# # Using store convenience method
# store.sync_variant_image(
#   shopify_variant_id: 12345,
#   image_url: "https://example.com/image.jpg"
# )
#
# # Using variant mapping convenience method
# variant_mapping.sync_to_shopify_variant(size: 1000)
#
# # Batch sync multiple variants
# variant_data = [
#   { shopify_variant_id: 12345, image_url: "https://example.com/image1.jpg" },
#   { shopify_variant_id: 67890, image_url: "https://example.com/image2.jpg" }
# ]
# results = service.batch_sync_variant_images(variant_data)
#
class ShopifyVariantImageSyncService
  attr_reader :store, :session

  def initialize(store)
    @store = store
    raise ArgumentError, "Store must be a Shopify store" unless store.shopify?
    raise ArgumentError, "Store must be connected to Shopify" unless store.shopify_token.present?

    @session = store.shopify_session
  end

  # Syncs an image to a specific Shopify variant
  # @param shopify_variant_id [Integer] The Shopify variant ID
  # @param image_url [String] The URL of the image to sync
  # @param shopify_product_id [Integer, nil] The Shopify product ID (optional, will be fetched if not provided)
  # @param alt_text [String, nil] Alt text for the image (optional)
  # @return [Hash] Result with success status and image details
  def sync_variant_image(shopify_variant_id:, image_url:, shopify_product_id: nil, alt_text: nil)
    Rails.logger.info "Starting variant image sync for variant #{shopify_variant_id} with image: #{image_url}"

    begin
      # Get product ID if not provided
      product_id = shopify_product_id || fetch_product_id_for_variant(shopify_variant_id)

      if product_id.nil?
        return {
          success: false,
          error: "Could not find product for variant #{shopify_variant_id}"
        }
      end

      Rails.logger.info "Found product ID #{product_id} for variant #{shopify_variant_id}"

      # Check if media already exists for this variant
      existing_media = find_existing_variant_media(product_id, shopify_variant_id)

      if existing_media
        Rails.logger.info "Found existing media #{existing_media['id']} for variant, updating..."
        result = update_variant_image(product_id, existing_media["id"], image_url, alt_text, shopify_variant_id)
      else
        Rails.logger.info "No existing media found, creating new image for variant..."
        result = create_variant_image(product_id, shopify_variant_id, image_url, alt_text)
      end

      if result[:success]
        Rails.logger.info "✅ Successfully synced image for variant #{shopify_variant_id}"
      else
        Rails.logger.error "❌ Failed to sync image for variant #{shopify_variant_id}: #{result[:error]}"
      end

      result

    rescue => e
      Rails.logger.error "❌ Error syncing variant image: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      {
        success: false,
        error: e.message
      }
    end
  end

  # Batch sync multiple variant images
  # @param variant_image_data [Array<Hash>] Array of hashes with keys: shopify_variant_id, image_url, shopify_product_id (optional), alt_text (optional)
  # @return [Hash] Summary of results
  def batch_sync_variant_images(variant_image_data)
    Rails.logger.info "Starting batch sync for #{variant_image_data.length} variant images"

    results = {
      total: variant_image_data.length,
      successful: 0,
      failed: 0,
      errors: []
    }

    variant_image_data.each_with_index do |data, index|
      Rails.logger.info "Processing variant image #{index + 1}/#{variant_image_data.length}"

      result = sync_variant_image(
        shopify_variant_id: data[:shopify_variant_id],
        image_url: data[:image_url],
        shopify_product_id: data[:shopify_product_id],
        alt_text: data[:alt_text]
      )

      if result[:success]
        results[:successful] += 1
      else
        results[:failed] += 1
        results[:errors] << {
          variant_id: data[:shopify_variant_id],
          error: result[:error]
        }
      end

      # Add delay between requests to respect rate limits and allow media processing
      sleep(1)
    end

    Rails.logger.info "Batch sync completed: #{results[:successful]} successful, #{results[:failed]} failed"
    results
  end

  private

  def graphql_client
    @graphql_client ||= ShopifyAPI::Clients::Graphql::Admin.new(session: session)
  end

  # Fetches the product ID for a given variant ID using GraphQL
  def fetch_product_id_for_variant(shopify_variant_id)
    Rails.logger.info "Fetching product ID for variant #{shopify_variant_id}"

    query = <<~GRAPHQL
      query GetProductFromVariant($id: ID!) {
        productVariant(id: $id) {
          id
          product {
            id
          }
        }
      }
    GRAPHQL

    variables = {
      "id" => "gid://shopify/ProductVariant/#{shopify_variant_id}"
    }

    response = graphql_client.query(query: query, variables: variables)

    if response.body.dig("data", "productVariant", "product", "id")
      product_gid = response.body["data"]["productVariant"]["product"]["id"]
      product_id = product_gid.split("/").last
      Rails.logger.info "Found product ID #{product_id} for variant #{shopify_variant_id}"
      product_id
    else
      Rails.logger.error "Failed to fetch variant #{shopify_variant_id}: #{response.body['errors']&.inspect}"
      nil
    end
  rescue => e
    Rails.logger.error "Error fetching product ID for variant #{shopify_variant_id}: #{e.message}"
    nil
  end

  # Finds existing media for a variant within a product using GraphQL
  def find_existing_variant_media(product_id, shopify_variant_id)
    Rails.logger.info "Looking for existing media for variant #{shopify_variant_id} in product #{product_id}"

    query = <<~GRAPHQL
      query GetVariantMedia($productId: ID!, $variantId: ID!) {
        product(id: $productId) {
          id
        }
        productVariant(id: $variantId) {
          id
          media(first: 10) {
            edges {
              node {
                id
                alt
                mediaContentType
                ... on MediaImage {
                  image {
                    url
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL

    variables = {
      "productId" => "gid://shopify/Product/#{product_id}",
      "variantId" => "gid://shopify/ProductVariant/#{shopify_variant_id}"
    }

    response = graphql_client.query(query: query, variables: variables)

    if response.body.dig("data", "productVariant", "media", "edges")
      media_edges = response.body["data"]["productVariant"]["media"]["edges"]
      existing_media = media_edges.first&.dig("node") # Get the first media item

      if existing_media
        Rails.logger.info "Found existing media #{existing_media['id']} for variant #{shopify_variant_id}"
      else
        Rails.logger.info "No existing media found for variant #{shopify_variant_id}"
      end

      existing_media
    else
      Rails.logger.error "Failed to fetch media for variant #{shopify_variant_id}: #{response.body['errors']&.inspect}"
      nil
    end
  rescue => e
    Rails.logger.error "Error finding existing variant media: #{e.message}"
    nil
  end

  # Creates a new image for a variant using GraphQL
  def create_variant_image(product_id, shopify_variant_id, image_url, alt_text = nil)
    Rails.logger.info "Creating new image for variant #{shopify_variant_id}"

    # Step 1: Add media to the product
    media_result = add_media_to_product(product_id, image_url, alt_text)
    return media_result unless media_result[:success]

    # Step 2: Wait for media to be ready, then associate it with the variant
    if wait_for_media_ready(media_result[:media_id])
      associate_result = associate_media_to_variant(product_id, shopify_variant_id, media_result[:media_id])

      if associate_result[:success]
        Rails.logger.info "✅ Successfully created and associated image for variant #{shopify_variant_id}"
        {
          success: true,
          media_id: media_result[:media_id],
          image_url: image_url,
          action: "created"
        }
      else
        associate_result
      end
    else
      {
        success: false,
        error: "Media failed to process or timed out waiting for ready status"
      }
    end
  end

  # Adds media to a product using GraphQL
  def add_media_to_product(product_id, image_url, alt_text = nil)
    Rails.logger.info "Adding media with title: '#{alt_text}'" if alt_text.present?
    
    mutation = <<~GRAPHQL
      mutation ProductUpdate($input: ProductInput!, $media: [CreateMediaInput!]) {
        productUpdate(input: $input, media: $media) {
          product {
            id
            media(first: 1, reverse: true) {
              edges {
                node {
                  id
                  alt
                  mediaContentType
                }
              }
            }
          }
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL

    variables = {
      "input" => {
        "id" => "gid://shopify/Product/#{product_id}"
      },
      "media" => [ {
        "originalSource" => image_url,
        "alt" => alt_text || "",
        "mediaContentType" => "IMAGE"
      } ]
    }

    response = graphql_client.query(query: mutation, variables: variables)

    if response.body.dig("data", "productUpdate", "userErrors")&.empty?
      media_edge = response.body.dig("data", "productUpdate", "product", "media", "edges")&.first
      if media_edge
        media_id = media_edge["node"]["id"]
        Rails.logger.info "Successfully added media #{media_id} to product #{product_id}"
        {
          success: true,
          media_id: media_id
        }
      else
        {
          success: false,
          error: "No media was created in the response"
        }
      end
    else
      errors = response.body.dig("data", "productUpdate", "userErrors") || response.body["errors"] || []
      error_message = extract_graphql_errors(errors)
      Rails.logger.error "Failed to add media to product #{product_id}: #{error_message}"
      {
        success: false,
        error: error_message
      }
    end
  rescue => e
    Rails.logger.error "Error adding media to product: #{e.message}"
    {
      success: false,
      error: e.message
    }
  end

  # Associates media with a variant using GraphQL
  def associate_media_to_variant(product_id, shopify_variant_id, media_id)
    mutation = <<~GRAPHQL
      mutation ProductVariantAppendMedia($productId: ID!, $variantMedia: [ProductVariantAppendMediaInput!]!) {
        productVariantAppendMedia(productId: $productId, variantMedia: $variantMedia) {
          product {
            id
          }
          productVariants {
            id
            media(first: 1) {
              edges {
                node {
                  id
                }
              }
            }
          }
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL

    variables = {
      "productId" => "gid://shopify/Product/#{product_id}",
      "variantMedia" => [ {
        "variantId" => "gid://shopify/ProductVariant/#{shopify_variant_id}",
        "mediaIds" => [ media_id ]
      } ]
    }

    response = graphql_client.query(query: mutation, variables: variables)

    if response.body.dig("data", "productVariantAppendMedia", "userErrors")&.empty?
      Rails.logger.info "Successfully associated media to variant #{shopify_variant_id}"
      {
        success: true
      }
    else
      errors = response.body.dig("data", "productVariantAppendMedia", "userErrors") || response.body["errors"] || []
      error_message = extract_graphql_errors(errors)
      Rails.logger.error "Failed to associate media to variant #{shopify_variant_id}: #{error_message}"
      {
        success: false,
        error: error_message
      }
    end
  rescue => e
    Rails.logger.error "Error associating media to variant: #{e.message}"
    {
      success: false,
      error: e.message
    }
  end

  # Updates an existing media for a variant using GraphQL
  def update_variant_image(product_id, media_id, image_url, alt_text = nil, shopify_variant_id = nil)
    Rails.logger.info "Updating existing media #{media_id}"

    # For GraphQL, we'll create new media since updating existing media content
    # requires more complex operations. This ensures we get the latest image.
    if shopify_variant_id
      create_variant_image(product_id, shopify_variant_id, image_url, alt_text)
    else
      {
        success: false,
        error: "Variant ID required for updating media"
      }
    end
  end

  # Waits for media to be ready for variant association
  def wait_for_media_ready(media_id, max_attempts = 10, wait_interval = 2)
    Rails.logger.info "Waiting for media #{media_id} to be ready..."

    query = <<~GRAPHQL
      query GetMediaStatus($id: ID!) {
        node(id: $id) {
          ... on MediaImage {
            id
            status
            preview {
              status
            }
          }
        }
      }
    GRAPHQL

    variables = { "id" => media_id }

    max_attempts.times do |attempt|
      begin
        response = graphql_client.query(query: query, variables: variables)

        if response.body.dig("data", "node")
          media_status = response.body["data"]["node"]["status"]
          preview_status = response.body.dig("data", "node", "preview", "status")

          Rails.logger.info "Media #{media_id} status: #{media_status}, preview status: #{preview_status}"

          # Check if both the media and preview are ready
          if media_status == "READY" && (preview_status.nil? || preview_status == "READY")
            Rails.logger.info "✅ Media #{media_id} is ready for variant association"
            return true
          elsif media_status == "FAILED"
            Rails.logger.error "❌ Media #{media_id} failed to process"
            return false
          end
        end

        # Wait before next attempt (except on last attempt)
        if attempt < max_attempts - 1
          Rails.logger.info "Media not ready yet, waiting #{wait_interval} seconds... (attempt #{attempt + 1}/#{max_attempts})"
          sleep(wait_interval)
        end

      rescue => e
        Rails.logger.error "Error checking media status: #{e.message}"
        return false
      end
    end

    Rails.logger.warn "⚠️ Media #{media_id} did not become ready within #{max_attempts * wait_interval} seconds"
    false
  end

  # Extracts error message from GraphQL response
  def extract_graphql_errors(errors)
    if errors.is_a?(Array)
      errors.map { |error| error["message"] || error.to_s }.join(", ")
    elsif errors.is_a?(Hash)
      errors["message"] || errors.to_s
    else
      "Unknown error occurred"
    end
  end
end
