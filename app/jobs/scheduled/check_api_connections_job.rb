module Scheduled
  class CheckApiConnectionsJob
    include Sidekiq::Job
    sidekiq_options queue: "default", retry: 1

    def perform
      Rake::Task["stores:check_api_connections"].invoke
    ensure
      Rake::Task["stores:check_api_connections"].reenable
    end
  end
end
