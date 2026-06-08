class CreateOrderXeroInvoiceJob < ApplicationJob
  queue_as :default

  retry_on XeroService::XeroError, OrderXeroInvoiceService::InvoiceError, wait: :polynomially_longer, attempts: 5

  def perform(order)
    OrderXeroInvoiceService.new(order: order).call(raise_on_failure: true)
  end
end
