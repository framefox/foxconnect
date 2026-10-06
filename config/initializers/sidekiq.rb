Sidekiq::Cron.configure do |config|
  config.cron_schedule_file = Rails.root.join("config/sidekiq_schedule.yml").to_s
  # If the worker is restarted after 5am, still run that day's sync.
  config.reschedule_grace_period = 12.hours.to_i
end

Sidekiq.configure_server do |config|
  config.redis = {
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
  }
end
