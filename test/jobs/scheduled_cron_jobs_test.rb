require "test_helper"
require "fugit"

class ScheduledCronJobsTest < ActiveSupport::TestCase
  JOBS = {
    "check_api_connections" => {
      "class" => "Scheduled::CheckApiConnectionsJob",
      "cron" => "0 0 * * * UTC",
      "task" => "stores:check_api_connections"
    },
    "sync_updated_products" => {
      "class" => "Scheduled::SyncUpdatedProductsJob",
      "cron" => "0 * * * *",
      "task" => "products:sync_updated"
    },
    "pending_payment_orders" => {
      "class" => "Scheduled::PendingPaymentOrdersJob",
      "cron" => "0 22 * * * UTC",
      "task" => "orders:pending_payments"
    },
    "draft_orders_reminder" => {
      "class" => "Scheduled::DraftOrdersReminderJob",
      "cron" => "0 21 * * * UTC",
      "task" => "orders:draft_reminder"
    },
    "send_weekly_statements" => {
      "class" => "Scheduled::SendWeeklyStatementsJob",
      "cron" => "0 22 * * * UTC",
      "task" => "xero:send_weekly_statements"
    }
  }.freeze

  test "schedule matches the Heroku Scheduler tasks" do
    schedule = YAML.load_file(Rails.root.join("config/sidekiq_schedule.yml"))

    JOBS.each do |name, expected|
      job = schedule.fetch(name)
      assert_equal expected["class"], job["class"]
      assert_equal expected["cron"], job["cron"]
      assert_nil job["active_job"]

      cron = Fugit::Cron.parse(job["cron"])
      assert cron, name
      assert_equal "UTC", cron.timezone.name if job["cron"].include?("UTC")
    end
  end

  test "each job invokes and reenables its rake task" do
    JOBS.each_value do |expected|
      task = Minitest::Mock.new
      task.expect(:invoke, nil)
      task.expect(:reenable, nil)
      names = []

      Rake::Task.stub(:[], ->(name) { names << name; task }) do
        expected["class"].constantize.new.perform
      end

      assert_equal [ expected["task"], expected["task"] ], names
      assert task.verify
    end
  end
end
