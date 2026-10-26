Sidekiq::Cron.configure do |config|
  config.cron_schedule_file = Rails.root.join("config/sidekiq_schedule.yml").to_s
  # If the worker is restarted after 5am, still run that day's sync.
  config.reschedule_grace_period = 12.hours.to_i
end

Sidekiq.configure_server do |config|
  config.on(:startup) do
    # Scheduled cron jobs invoke rake tasks. The Sidekiq process does not load them otherwise.
    Rails.application.load_tasks
  end
end
