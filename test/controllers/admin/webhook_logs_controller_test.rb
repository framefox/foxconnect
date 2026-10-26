require "test_helper"

class Admin::WebhookLogsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    org = Organization.create!(name: "Webhook admin test")
    @admin = User.create!(email: "webhook-admin-#{SecureRandom.hex(5)}@example.com", password: "password123",
      admin: true, organization: org, country: "NZ")
    @log = WebhookLog.create!(topic: "orders/create", shop_domain: "test.myshopify.com", payload: { id: 123 },
      status_code: 500, delivery_state: "needs_review", delivery_subject_id: "123", delivery_attempts: 1,
      error_message: "Order not found with ID: 123")
  end

  test "review list shows distinct events, attempts and errors and permits recorded retirement" do
    sign_in @admin, scope: :user
    get admin_webhook_logs_path(status_category: "needs_review")
    assert_response :success
    assert_includes response.body, "1 webhook events need review"
    assert_includes response.body, "Order ID: 123"
    assert_includes response.body, "Order not found with ID: 123"
    get admin_webhook_log_path(@log)
    assert_response :success
    assert_includes response.body, "Retire event"
    post retire_admin_webhook_log_path(@log), params: { reason: "Owner confirmed this is obsolete" }
    assert_redirected_to admin_webhook_log_path(@log)
    assert_equal "retired", @log.reload.delivery_state
    assert_equal @admin.id, @log.retired_by_user_id
    follow_redirect!
    assert_includes response.body, "Owner confirmed this is obsolete"
  end

  test "blank reason leaves delivery unchanged" do
    sign_in @admin, scope: :user
    post retire_admin_webhook_log_path(@log), params: { reason: " " }
    assert_redirected_to admin_webhook_log_path(@log)
    assert_equal "needs_review", @log.reload.delivery_state
  end

  test "non-admin cannot retire an event" do
    @admin.update!(admin: false)
    sign_in @admin, scope: :user
    post retire_admin_webhook_log_path(@log), params: { reason: "Not allowed" }
    assert_redirected_to root_path
    assert_equal "needs_review", @log.reload.delivery_state
  end
end
