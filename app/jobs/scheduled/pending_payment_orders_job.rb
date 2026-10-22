module Scheduled
  class PendingPaymentOrdersJob
    include Sidekiq::Job
    sidekiq_options queue: "default", retry: 1

    def perform
      Rake::Task["orders:pending_payments"].invoke
    ensure
      Rake::Task["orders:pending_payments"].reenable
    end
  end
end
