# Test boot can happen before test_helper (for example through asset build tasks).
if Rails.env.test?
  ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"] ||= "test-primary-key-32-characters-ok"
  ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"] ||= "test-deterministic-key-32-chars-ok"
  ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"] ||= "test-key-derivation-salt"
end

# Configure Active Record encryption to use environment variables
# This is required for encrypted attributes like WebhookLog.payload_ciphertext

Rails.application.config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
Rails.application.config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
Rails.application.config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
