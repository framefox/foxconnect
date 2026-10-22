module Scheduled
  class DraftOrdersReminderJob
    include Sidekiq::Job
    sidekiq_options queue: "default", retry: 1

    def perform
      Rake::Task["orders:draft_reminder"].invoke
    ensure
      Rake::Task["orders:draft_reminder"].reenable
    end
  end
end
