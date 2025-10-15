module Shopify
  class DraftOrderService
    attr_reader :order, :draft_order_gid, :graphql_client

    def initialize(order:, draft_order_gid:)
      @order = order
      @draft_order_gid = draft_order_gid
      @graphql_client = Shopify::GraphqlClient.new(order: order)
    end

    # Orchestrates the complete draft order process
    def complete
      Rails.logger.info "Completing Shopify draft order: #{draft_order_gid}"

      # First update with customer and shipping details
      update_result = update_customer
      return false unless update_result

      # Apply shipping rates
      shipping_service = Shopify::DraftOrderShippingService.new(
        order: order,
        draft_order_gid: draft_order_gid
      )
      shipping_service.apply_shipping

      # Then complete the draft order
      complete_result = finalize
      Rails.logger.info "Draft order completion result: #{complete_result ? 'success' : 'failed'}"
      complete_result
    end

    # Updates draft order with customer and company details
    def update_customer
      mutation = <<~GRAPHQL
        mutation draftOrderUpdate($id: ID!, $input: DraftOrderInput!) {
          draftOrderUpdate(id: $id, input: $input) {
            draftOrder { id name }
            userErrors { field message }
          }
        }
      GRAPHQL

      variables = {
        id: draft_order_gid,
        input: build_customer_input
      }

      Rails.logger.info "Updating draft order with variables:"
      Rails.logger.info JSON.pretty_generate(variables)

      response = graphql_client.query(mutation, variables)
      return false unless response

      result = response.body

      if result&.dig("data", "draftOrderUpdate", "userErrors")&.any?
        errors = result["data"]["draftOrderUpdate"]["userErrors"]
        Rails.logger.error "Draft order update errors: #{errors.inspect}"
        return false
      end

      Rails.logger.info "Successfully updated draft order with customer details"
      true
    rescue => e
      Rails.logger.error "Error updating draft order customer: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      false
    end

    # Completes the draft order and creates the Shopify order
    def finalize
      mutation = <<~GRAPHQL
        mutation draftOrderComplete($id: ID!, $paymentPending: Boolean) {
          draftOrderComplete(id: $id, paymentPending: $paymentPending) {
            draftOrder {
              order {
                id
                name
                subtotalPriceSet {
                  shopMoney {
                    amount
                    currencyCode
                  }
                }
                totalShippingPriceSet {
                  shopMoney {
                    amount
                    currencyCode
                  }
                }
                totalPriceSet {
                  shopMoney {
                    amount
                    currencyCode
                  }
                }
                lineItems(first: 100) {
                  edges {
                    node {
                      id
                      originalUnitPriceSet {
                        shopMoney {
                          amount
                          currencyCode
                        }
                      }
                      customAttributes {
                        key
                        value
                      }
                    }
                  }
                }
              }
            }
            userErrors { field message }
          }
        }
      GRAPHQL

      variables = {
        id: draft_order_gid,
        paymentPending: true
      }

      Rails.logger.info "Completing draft order with paymentPending: true (B2B deferred payment)"
      response = graphql_client.query(mutation, variables)
      return false unless response

      result = response.body

      if result&.dig("data", "draftOrderComplete", "userErrors")&.any?
        errors = result["data"]["draftOrderComplete"]["userErrors"]
        Rails.logger.error "Draft order completion errors: #{errors}"
        return false
      end

      # Log and save the created order
      if order_data = result&.dig("data", "draftOrderComplete", "draftOrder", "order")
        cost_service = Production::CostService.new(order: order)
        cost_service.save_order_costs(order_data)
        cost_service.save_line_item_costs(order_data["lineItems"])
      end

      true
    rescue => e
      Rails.logger.error "Error completing draft order: #{e.message}"
      false
    end

    private

    def build_customer_input
      input = {}

      # Add B2B purchasing entity (company information)
      # ALL orders in this service are B2B orders
      # Find the shopify_customer for this order's country
      user = order.store.user

      shopify_customer = user.shopify_customers.find_by(country_code: order.country_code)
      raise "User #{user.email} has no Shopify customer for country #{order.country_code}" unless shopify_customer

      if company = shopify_customer.company
        # Build full GIDs - IDs in database are stored without gid:// prefix
        company_gid = graphql_client.build_gid("Company", company.shopify_company_id)
        location_gid = graphql_client.build_gid("CompanyLocation", company.shopify_company_location_id)
        contact_gid = graphql_client.build_gid("CompanyContact", company.shopify_company_contact_id)

        input[:purchasingEntity] = {
          purchasingCompany: {
            companyId: company_gid,
            companyLocationId: location_gid,
            companyContactId: contact_gid
          }
        }

        Rails.logger.info "Adding B2B purchasingEntity for company: #{company.company_name}"
        Rails.logger.info "  Company GID: #{company_gid}"
        Rails.logger.info "  Location GID: #{location_gid}"
        Rails.logger.info "  Contact GID: #{contact_gid}"
      else
        Rails.logger.warn "Order #{order.display_name} has no company association - B2B order requires company!"
      end

      # Add shipping address if available
      if order.shipping_address
        addr = order.shipping_address
        shipping_address = {
          firstName: addr.first_name,
          lastName: addr.last_name,
          company: addr.company,
          address1: addr.address1,
          address2: addr.address2,
          city: addr.city,
          province: addr.province,
          zip: addr.postal_code,
          country: addr.country,
          phone: addr.phone || order.customer_phone
        }.compact

        input[:shippingAddress] = shipping_address
        input[:billingAddress] = shipping_address
      end

      # Add customer info from order
      if order.customer_email.present?
        input[:email] = order.customer_email
      end

      # Add pro-platform tag
      input[:tags] = [ "framefox-connect" ]

      input
    end
  end
end
