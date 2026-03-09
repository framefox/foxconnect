class Admin::InvoiceRunsController < Admin::ApplicationController
  before_action :set_invoice_run, only: [ :show, :destroy ]

  def index
    @pagy, @invoice_runs = pagy(
      InvoiceRun.includes(:company, :invoice_run_line_items).recent_first,
      items: 25
    )
  end

  def show
    @line_items = @invoice_run.invoice_run_line_items.order(:shopify_order_name)
  end

  def destroy
    company_name = @invoice_run.company.company_name
    invoice_number = @invoice_run.xero_invoice_number
    @invoice_run.destroy
    redirect_to admin_invoice_runs_path,
      notice: "Invoice run #{invoice_number} for #{company_name} deleted. Remember to also delete the invoice in Xero."
  end

  private

  def set_invoice_run
    @invoice_run = InvoiceRun.find(params[:id])
  end
end
