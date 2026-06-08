class Admin::StatementRunsController < Admin::ApplicationController
  before_action :set_statement_run, only: [ :show, :destroy, :archive ]

  def index
    scope = StatementRun.includes(:company, :statement_run_line_items)
    scope = params[:status] == "archived" ? scope.archived : scope.active
    @pagy, @statement_runs = pagy(scope.recent_first, items: 25)
  end

  def show
    @line_items = @statement_run.statement_run_line_items.includes(order: :shipping_address).order(:invoiced_at)
  end

  def destroy
    company_name = @statement_run.company.company_name
    period_label = @statement_run.period_label
    @statement_run.destroy
    redirect_to admin_statement_runs_path,
      notice: "Statement for #{company_name} (#{period_label}) deleted."
  end

  def archive
    @statement_run.update!(status: "archived")
    redirect_to admin_statement_runs_path,
      notice: "Statement for #{@statement_run.company.company_name} (#{@statement_run.period_label}) archived."
  end

  private

  def set_statement_run
    @statement_run = StatementRun.find(params[:id])
  end
end
