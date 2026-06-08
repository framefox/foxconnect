require "test_helper"
require "ostruct"

class Shopify::DraftOrderServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class FakeGraphqlClient
    attr_reader :body

    def initialize(body)
      @body = body
    end

    def query(_query, _variables)
      OpenStruct.new(body: body)
    end
  end

  class FailedInvoiceService
    def call
      { success: false, error: "Xero unavailable" }
    end
  end

  test "finalize succeeds when Xero invoice creation fails after Shopify order completion" do
    order = create_order!
    service = Shopify::DraftOrderService.new(order: order, draft_order_gid: "gid://shopify/DraftOrder/1")
    service.instance_variable_set(:@graphql_client, FakeGraphqlClient.new(successful_completion_body))

    clear_enqueued_jobs
    with_order_xero_invoice_service(FailedInvoiceService.new) do
      assert_enqueued_jobs 1, only: CreateOrderXeroInvoiceJob do
        assert service.finalize
      end
    end

    order.reload
    assert_equal "987654321", order.shopify_remote_order_id
    assert_equal "#2001", order.shopify_remote_order_name
    assert_equal 12_000, order.production_subtotal_cents
    assert_equal 1_500, order.production_shipping_cents
    assert_equal 13_500, order.production_total_cents
  end

  private

  def with_order_xero_invoice_service(fake_service)
    original_new = OrderXeroInvoiceService.method(:new)
    OrderXeroInvoiceService.define_singleton_method(:new) { |*_args, **_kwargs| fake_service }
    yield
  ensure
    OrderXeroInvoiceService.define_singleton_method(:new) { |*args, **kwargs| original_new.call(*args, **kwargs) }
  end

  def successful_completion_body
    {
      "data" => {
        "draftOrderComplete" => {
          "draftOrder" => {
            "order" => {
              "id" => "gid://shopify/Order/987654321",
              "name" => "#2001",
              "subtotalPriceSet" => { "shopMoney" => { "amount" => "120.00", "currencyCode" => "NZD" } },
              "totalShippingPriceSet" => { "shopMoney" => { "amount" => "15.00", "currencyCode" => "NZD" } },
              "totalPriceSet" => { "shopMoney" => { "amount" => "135.00", "currencyCode" => "NZD" } },
              "lineItems" => { "edges" => [] }
            }
          },
          "userErrors" => []
        }
      }
    }
  end

  def create_order!
    suffix = SecureRandom.hex(6)
    organization = Organization.create!(name: "Draft Order Test #{suffix}")

    Order.create!(
      organization: organization,
      external_id: "draft-order-#{suffix}",
      currency: "NZD",
      fulfillment_currency: "NZD",
      country_code: "NZ",
      subtotal_price_cents: 0,
      total_discounts_cents: 0,
      total_shipping_cents: 0,
      total_tax_cents: 0,
      total_price_cents: 0,
      production_subtotal_cents: 0,
      production_shipping_cents: 0,
      production_total_cents: 0
    )
  end
end
