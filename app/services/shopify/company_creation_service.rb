module Shopify
  class CompanyCreationService
    attr_reader :shopify_customer, :country_config

    def initialize(shopify_customer:)
      @shopify_customer = shopify_customer
      @country_config = CountryConfig.for_country(shopify_customer.country_code)

      raise "Country config not found for #{shopify_customer.country_code}" unless @country_config
      raise "Shopify credentials not configured for #{shopify_customer.country_code}" unless @country_config["shopify_domain"].present? && @country_config["shopify_access_token"].present?
    end

    def call
      Rails.logger.info "Creating company for ShopifyCustomer #{shopify_customer.id} (External ID: #{shopify_customer.external_shopify_id})"

      # Query Shopify for company information
      company_data = fetch_company_data

      # Validate we got company data
      validate_company_data!(company_data)

      # Create the company record
      create_company!(company_data)
    end

    private

    def fetch_company_data
      query = <<~GRAPHQL
        query getCustomerCompanies($customerId: ID!) {
          customer(id: $customerId) {
            id
            companyContactProfiles {
              id
              company {
                id
                name
                locations(first: 1) {
                  edges {
                    node {
                      id
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL

      # Build the customer GID
      customer_gid = "gid://shopify/Customer/#{shopify_customer.external_shopify_id}"

      variables = {
        customerId: customer_gid
      }

      Rails.logger.info "Querying Shopify for customer companies with GID: #{customer_gid}"

      response = graphql_client.query(query: query, variables: variables)

      unless response
        raise "Failed to query Shopify API"
      end

      result = response.body

      if result&.dig("errors")
        errors = result["errors"]
        Rails.logger.error "GraphQL errors: #{errors.inspect}"
        raise "Shopify API returned errors: #{errors.map { |e| e["message"] }.join(", ")}"
      end

      result&.dig("data", "customer")
    end

    def validate_company_data!(company_data)
      unless company_data
        raise "Customer not found in Shopify"
      end

      company_profiles = company_data["companyContactProfiles"]

      if company_profiles.nil? || company_profiles.empty?
        raise "Customer has no company profiles in Shopify"
      end

      first_profile = company_profiles.first
      company = first_profile["company"]
      locations = company&.dig("locations", "edges")

      unless company && company["name"].present?
        raise "Company data is incomplete - missing company name"
      end

      unless locations && locations.any?
        raise "Company has no locations"
      end

      # Check if company already exists
      company_id = extract_id_from_gid(company["id"])
      if Company.exists?(shopify_company_id: company_id)
        raise "Company with Shopify ID #{company_id} already exists"
      end
    end

    def create_company!(company_data)
      first_profile = company_data["companyContactProfiles"].first
      company = first_profile["company"]
      first_location = company["locations"]["edges"].first["node"]

      # Extract IDs from GIDs
      company_id = extract_id_from_gid(company["id"])
      location_id = extract_id_from_gid(first_location["id"])
      contact_id = extract_id_from_gid(first_profile["id"])

      Rails.logger.info "Creating Company record:"
      Rails.logger.info "  Name: #{company["name"]}"
      Rails.logger.info "  Company ID: #{company_id}"
      Rails.logger.info "  Location ID: #{location_id}"
      Rails.logger.info "  Contact ID: #{contact_id}"

      # Create the company
      new_company = Company.create!(
        company_name: company["name"],
        shopify_company_id: company_id,
        shopify_company_location_id: location_id,
        shopify_company_contact_id: contact_id
      )

      # Associate with the shopify customer
      shopify_customer.update!(company: new_company)

      Rails.logger.info "Successfully created Company #{new_company.id} and associated with ShopifyCustomer #{shopify_customer.id}"

      new_company
    end

    def extract_id_from_gid(gid)
      # Extract the numeric ID from a GID like "gid://shopify/Company/123"
      gid.to_s.split("/").last
    end

    def graphql_client
      @graphql_client ||= begin
        shop = country_config["shopify_domain"]
        token = country_config["shopify_access_token"]

        session = ShopifyAPI::Auth::Session.new(
          shop: shop,
          access_token: token
        )

        ShopifyAPI::Clients::Graphql::Admin.new(session: session)
      end
    end
  end
end
