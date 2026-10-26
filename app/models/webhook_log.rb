class WebhookLog < ApplicationRecord
  # Encrypt the payload since it contains PII (customer data from webhooks)
  encrypts :payload_ciphertext

  # Associations
  belongs_to :store, optional: true

  # Validations
  validates :topic, presence: true
  validates :status_code, presence: true

  def managed_delivery?
    Shopify::WebhookDelivery::TOPICS.include?(topic)
  end

  def delivery_terminal?
    processed_at? || %w[completed needs_review retired].include?(delivery_state)
  end

  def delivery_label
    return "Retired" if delivery_state == "retired"
    return "Completed" if processed_at?
    delivery_state.humanize
  end

  def retire!(user:, reason:)
    raise ArgumentError, "A retirement reason is required" if reason.blank?
    Shopify::Lock.with(:delivery, id) do
      with_lock do
        raise ArgumentError, "Only unresolved webhook deliveries can be retired" unless managed_delivery? && !processed_at? && delivery_state != "retired"
        update!(delivery_state: "retired", retired_at: Time.current, retired_by_user_id: user.id,
          retirement_reason: reason, processed_at: Time.current, delivery_job_id: nil, next_attempt_at: nil)
      end
    end
  end

  # Virtual attribute to handle payload as JSON
  def payload
    return nil if payload_ciphertext.blank?

    JSON.parse(payload_ciphertext)
  rescue JSON::ParserError
    payload_ciphertext
  end

  def payload=(value)
    self.payload_ciphertext = value.is_a?(String) ? value : value.to_json
  end

  # Scopes
  scope :failed, -> { where.not(status_code: 200..299) }
  scope :successful, -> { where(status_code: 200..299) }
  scope :by_topic, ->(topic) { where(topic: topic) if topic.present? }
  scope :by_shop, ->(domain) { where(shop_domain: domain) if domain.present? }
  scope :by_status, ->(status) { where(status_code: status) if status.present? }
  scope :recent, -> { order(created_at: :desc) }

  # Class methods
  def self.cleanup_old_records!(days: 30)
    deleted_count = where.not(delivery_state: %w[needs_review retired]).where("created_at < ?", days.days.ago).where.not(status_code: [ 0, 202 ]).where("processed_at IS NOT NULL OR status_code BETWEEN 200 AND 299").delete_all
    Rails.logger.info "WebhookLog: Cleaned up #{deleted_count} records older than #{days} days"
    deleted_count
  end

  def self.available_topics
    distinct.pluck(:topic).compact.sort
  end

  def self.available_status_codes
    distinct.pluck(:status_code).compact.sort
  end

  def self.available_shop_domains
    distinct.pluck(:shop_domain).compact.sort
  end

  # Instance methods
  def success?
    status_code.between?(200, 299)
  end

  def client_error?
    status_code.between?(400, 499)
  end

  def server_error?
    status_code.between?(500, 599)
  end

  def status_category
    case status_code
    when 200..299 then :success
    when 400..499 then :client_error
    when 500..599 then :server_error
    else :unknown
    end
  end

  def formatted_processing_time
    return "—" unless processing_time_ms

    if processing_time_ms < 1000
      "#{processing_time_ms}ms"
    else
      "#{(processing_time_ms / 1000.0).round(2)}s"
    end
  end

  def formatted_headers
    return {} unless headers

    headers.is_a?(String) ? JSON.parse(headers) : headers
  rescue JSON::ParserError
    {}
  end
end
