module Scheduled
  class SendWeeklyStatementsJob
    include Sidekiq::Job
    sidekiq_options queue: "default", retry: 1

    def perform
      Rake::Task["xero:send_weekly_statements"].invoke
    ensure
      Rake::Task["xero:send_weekly_statements"].reenable
    end
  end
end
