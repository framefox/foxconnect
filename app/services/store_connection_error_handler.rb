# Service for handling API connection errors and flagging stores that need reauthentication
#
# Usage:
#   handler = StoreConnectionErrorHandler.new(store)
#   
#   # Check and handle error message
#   handler.handle_error(error_message)
#   
#   # Check if error is auth-related
#   handler.auth_error?("Invalid API key")  # => true
#
class StoreConnectionErrorHandler
  attr_reader :store

  def initialize(store)
    @store = store
  end

  # Handles an error by checking if it's auth-related and flagging the store if needed
  # @param error_message [String] The error message to check
  # @return [Boolean] True if the error was an auth error and store was flagged
  def handle_error(error_message)
    return false unless auth_error?(error_message)

    flag_for_reauthentication
    true
  end

  # Checks if an error message indicates an authentication issue
  # @param message [String, Hash, Array] The error message to check
  # @return [Boolean] True if this is an auth error
  def auth_error?(message)
    error_str = extract_error_string(message)
    error_str.downcase.match?(/invalid|unauthorized|token|access|authentication|credentials/)
  end

  # Flags the store as needing reauthentication and sends notification
  # Only sends email if this is the first time being flagged
  def flag_for_reauthentication
    return if store.needs_reauthentication? # Already flagged

    Rails.logger.warn "Flagging store #{store.name} (#{store.shopify_domain}) for reauthentication"

    store.update!(
      needs_reauthentication: true,
      reauthentication_flagged_at: Time.current
    )

    # Send notification email to store owner
    send_notification_email
  end

  # Clears the reauthentication flag when connection is restored
  def clear_reauthentication_flag
    return unless store.needs_reauthentication?

    Rails.logger.info "Clearing reauthentication flag for store #{store.name} (#{store.shopify_domain})"

    store.update!(
      needs_reauthentication: false,
      reauthentication_flagged_at: nil
    )
  end

  private

  def extract_error_string(message)
    case message
    when String
      message
    when Hash
      message["message"] || message.to_s
    when Array
      message.map { |m| extract_error_string(m) }.join(", ")
    else
      message.to_s
    end
  end

  def send_notification_email
    return unless store.user&.email.present?

    begin
      StoreMailer.with(store: store).reauthentication_required.deliver_later
      Rails.logger.info "Reauthentication notification email queued for #{store.user.email}"
    rescue => e
      Rails.logger.error "Failed to send reauthentication email for store #{store.id}: #{e.message}"
    end
  end
end

