# Service for syncing variant images to Squarespace using REST API
#
# Usage Examples:
#
# # Basic usage - sync single variant image
# service = SquarespaceVariantImageSyncService.new(store)
# result = service.sync_variant_image(
#   squarespace_variant_id: "abc123",
#   squarespace_product_id: "xyz789",
#   image_url: "https://example.com/image.jpg",
#   alt_text: "Custom variant image"
# )
#
# # Using store convenience method
# store.sync_squarespace_variant_image(
#   squarespace_variant_id: "abc123",
#   squarespace_product_id: "xyz789",
#   image_url: "https://example.com/image.jpg"
# )
#
# # Using variant mapping convenience method
# variant_mapping.sync_to_squarespace_variant(size: 1000)
#
# # Batch sync multiple variants
# variant_data = [
#   { squarespace_variant_id: "abc123", squarespace_product_id: "xyz789", image_url: "https://example.com/image1.jpg" },
#   { squarespace_variant_id: "def456", squarespace_product_id: "xyz789", image_url: "https://example.com/image2.jpg" }
# ]
# results = service.batch_sync_variant_images(variant_data)
#
class SquarespaceVariantImageSyncService
  attr_reader :store, :api_client

  def initialize(store)
    @store = store
    raise ArgumentError, "Store must be a Squarespace store" unless store.squarespace?
    raise ArgumentError, "Store must be connected to Squarespace" unless store.squarespace_token.present?

    @api_client = store.squarespace_api_client
  end

  # Syncs an image to a specific Squarespace variant
  # @param squarespace_variant_id [String] The Squarespace variant ID
  # @param squarespace_product_id [String] The Squarespace product ID
  # @param image_url [String] The URL of the image to sync
  # @param alt_text [String, nil] Alt text for the image (optional, used as filename)
  # @return [Hash] Result with success status and image details
  def sync_variant_image(squarespace_variant_id:, squarespace_product_id:, image_url:, alt_text: nil)
    Rails.logger.info "Starting variant image sync for variant #{squarespace_variant_id} with image: #{image_url}"

    begin
      # Generate filename from alt_text or use default
      filename = generate_filename(alt_text, squarespace_variant_id)

      # Step 1: Upload image to product
      Rails.logger.info "Uploading image to product #{squarespace_product_id}..."
      upload_result = upload_image_to_product(squarespace_product_id, image_url, filename)

      unless upload_result[:success]
        Rails.logger.error "Failed to upload image: #{upload_result[:error]}"
        return upload_result
      end

      image_id = upload_result[:image_id]
      Rails.logger.info "Image uploaded successfully with ID: #{image_id}"

      # Step 2: Poll for image ready status
      Rails.logger.info "Polling for image ready status..."
      poll_result = poll_image_status(squarespace_product_id, image_id)

      unless poll_result[:success]
        Rails.logger.error "Image processing failed: #{poll_result[:error]}"
        return poll_result
      end

      Rails.logger.info "Image is ready, assigning to variant..."

      # Step 3: Assign image to variant
      assign_result = assign_image_to_variant(squarespace_product_id, squarespace_variant_id, image_id)

      if assign_result[:success]
        Rails.logger.info "✅ Successfully synced image for variant #{squarespace_variant_id}"
        {
          success: true,
          image_id: image_id,
          image_url: image_url,
          action: "created_and_assigned"
        }
      else
        Rails.logger.error "Failed to assign image to variant: #{assign_result[:error]}"
        assign_result
      end

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
  # @param variant_image_data [Array<Hash>] Array of hashes with keys: squarespace_variant_id, squarespace_product_id, image_url, alt_text (optional)
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
        squarespace_variant_id: data[:squarespace_variant_id],
        squarespace_product_id: data[:squarespace_product_id],
        image_url: data[:image_url],
        alt_text: data[:alt_text]
      )

      if result[:success]
        results[:successful] += 1
      else
        results[:failed] += 1
        results[:errors] << {
          variant_id: data[:squarespace_variant_id],
          error: result[:error]
        }
      end

      # Add delay between requests to respect rate limits
      sleep(1)
    end

    Rails.logger.info "Batch sync completed: #{results[:successful]} successful, #{results[:failed]} failed"
    results
  end

  private

  # Upload image to product
  # @param product_id [String] Squarespace product ID
  # @param image_url [String] URL of the image to upload
  # @param filename [String] Filename for the image
  # @return [Hash] Result with success status and image_id
  def upload_image_to_product(product_id, image_url, filename)
    begin
      response = api_client.upload_product_image(product_id, image_url, filename)
      
      if response["imageId"].present?
        {
          success: true,
          image_id: response["imageId"]
        }
      else
        {
          success: false,
          error: "No imageId returned from upload"
        }
      end
    rescue => e
      Rails.logger.error "Error uploading image: #{e.message}"
      {
        success: false,
        error: e.message
      }
    end
  end

  # Poll for image ready status
  # @param product_id [String] Squarespace product ID
  # @param image_id [String] Image ID to check status for
  # @param max_attempts [Integer] Maximum number of polling attempts
  # @param interval [Integer] Seconds to wait between polls
  # @return [Hash] Result with success status
  def poll_image_status(product_id, image_id, max_attempts: 30, interval: 2)
    attempts = 0

    while attempts < max_attempts
      begin
        status_response = api_client.get_image_status(product_id, image_id)
        status = status_response["status"]

        Rails.logger.info "Image status: #{status} (attempt #{attempts + 1}/#{max_attempts})"

        case status
        when "READY"
          return { success: true, status: "READY" }
        when "ERROR"
          return { success: false, error: "Image processing failed" }
        when "PROCESSING"
          # Continue polling
          attempts += 1
          sleep(interval) unless attempts >= max_attempts
        else
          Rails.logger.warn "Unknown image status: #{status}"
          attempts += 1
          sleep(interval) unless attempts >= max_attempts
        end
      rescue => e
        Rails.logger.error "Error polling image status: #{e.message}"
        return { success: false, error: e.message }
      end
    end

    # Timeout
    {
      success: false,
      error: "Image processing timed out after #{max_attempts * interval} seconds"
    }
  end

  # Assign image to variant
  # @param product_id [String] Squarespace product ID
  # @param variant_id [String] Squarespace variant ID
  # @param image_id [String] Image ID to assign
  # @return [Hash] Result with success status
  def assign_image_to_variant(product_id, variant_id, image_id)
    begin
      api_client.assign_image_to_variant(product_id, variant_id, image_id)
      
      {
        success: true,
        action: "assigned"
      }
    rescue => e
      Rails.logger.error "Error assigning image to variant: #{e.message}"
      {
        success: false,
        error: e.message
      }
    end
  end

  # Generate a filename from alt text or variant ID
  # @param alt_text [String, nil] Optional alt text
  # @param variant_id [String] Variant ID for fallback
  # @return [String] Filename
  def generate_filename(alt_text, variant_id)
    if alt_text.present?
      # Sanitize alt text for filename
      sanitized = alt_text.parameterize
      "#{sanitized}.jpg"
    else
      "variant-#{variant_id}.jpg"
    end
  end
end

