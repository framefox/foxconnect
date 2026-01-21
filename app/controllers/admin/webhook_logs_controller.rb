class Admin::WebhookLogsController < Admin::ApplicationController
  def index
    @webhook_logs = WebhookLog.includes(:store).order(created_at: :desc)

    # Filter by topic
    @webhook_logs = @webhook_logs.by_topic(params[:topic]) if params[:topic].present?

    # Filter by status code
    @webhook_logs = @webhook_logs.by_status(params[:status]) if params[:status].present?

    # Filter by shop domain
    @webhook_logs = @webhook_logs.by_shop(params[:shop_domain]) if params[:shop_domain].present?

    # Filter by status category
    case params[:status_category]
    when "success"
      @webhook_logs = @webhook_logs.successful
    when "failed"
      @webhook_logs = @webhook_logs.failed
    end

    @pagy, @webhook_logs = pagy(@webhook_logs, limit: 50)

    # For filter dropdowns
    @available_topics = WebhookLog.available_topics
    @available_status_codes = WebhookLog.available_status_codes
    @available_shop_domains = WebhookLog.available_shop_domains
  end

  def show
    @webhook_log = WebhookLog.includes(:store).find(params[:id])
  end
end
