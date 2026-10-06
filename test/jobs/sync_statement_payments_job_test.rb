require "test_helper"
require "fugit"
require "minitest/mock"

class SyncStatementPaymentsJobTest < ActiveJob::TestCase
  test "delegates to the statement payment sync" do
    called = false
    service = Object.new
    service.define_singleton_method(:call) { called = true }

    SyncStatementPaymentsService.stub :new, ->(*) { service } do
      SyncStatementPaymentsJob.perform_now
    end

    assert called
  end

  test "is scheduled daily at 5am New Zealand time" do
    schedule = YAML.load_file(Rails.root.join("config/sidekiq_schedule.yml"))
    job = schedule.fetch("sync_statement_payments")

    assert_equal "SyncStatementPaymentsJob", job["class"]
    assert_equal true, job["active_job"]
    assert_equal "0 5 * * * Pacific/Auckland", job["cron"]

    cron = Fugit::Cron.parse(job["cron"])
    assert cron
    assert_equal "Pacific/Auckland", cron.timezone.name
  end
end
