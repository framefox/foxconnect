# Strips any recipient whose User record has opted out of notifications
# (subscribed_to_notifications = false) from outgoing *activity* emails
# (orders, invoices, order reminders, etc.). Only emails flagged with the
# ACTIVITY_HEADER are filtered, so system/auth emails (Devise password
# resets, welcome invitations, store reauthentication) are always delivered.
# If no recipients remain after filtering, delivery is cancelled entirely.
class NotificationSubscriptionInterceptor
  RECIPIENT_FIELDS = %i[to cc bcc].freeze
  ACTIVITY_HEADER = "X-Activity-Notification".freeze

  def self.delivering_email(message)
    return unless activity_notification?(message)

    # Consume the marker header so it never leaks to recipients.
    message.header[ACTIVITY_HEADER] = nil

    unsubscribed = unsubscribed_emails(message)
    return if unsubscribed.empty?

    RECIPIENT_FIELDS.each do |field|
      addresses = Array(message.public_send(field))
      next if addresses.empty?

      remaining = addresses.reject { |address| unsubscribed.include?(address.to_s.downcase) }
      message.public_send("#{field}=", remaining)
    end

    if RECIPIENT_FIELDS.all? { |field| Array(message.public_send(field)).empty? }
      message.perform_deliveries = false
    end
  end

  def self.activity_notification?(message)
    message.header[ACTIVITY_HEADER].present?
  end

  def self.unsubscribed_emails(message)
    addresses = RECIPIENT_FIELDS.flat_map { |field| Array(message.public_send(field)) }
                                .map { |address| address.to_s.downcase }
                                .uniq
    return [] if addresses.empty?

    User.where("LOWER(email) IN (?)", addresses)
        .where(subscribed_to_notifications: false)
        .pluck(:email)
        .map(&:downcase)
  end
end
