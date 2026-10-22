module Scheduled
  class SyncUpdatedProductsJob
    include Sidekiq::Job
    sidekiq_options queue: "default", retry: 1

    def perform
      Rake::Task["products:sync_updated"].invoke
    ensure
      Rake::Task["products:sync_updated"].reenable
    end
  end
end
