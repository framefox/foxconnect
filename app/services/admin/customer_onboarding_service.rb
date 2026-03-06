module Admin
  class CustomerOnboardingService
    class OnboardingError < StandardError; end

    attr_reader :external_shopify_id, :country_code, :country_config

    def initialize(external_shopify_id:, country_code:)
      @external_shopify_id = external_shopify_id.to_i
      @country_code = country_code.to_s.upcase

      @country_config = CountryConfig.for_country(@country_code)
      raise OnboardingError, "Country config not found for #{@country_code}" unless @country_config
      raise OnboardingError, "Shopify credentials not configured for #{@country_code}" unless @country_config["shopify_domain"].present? && @country_config["shopify_access_token"].present?
    end

    def call
      customer_data = fetch_customer_from_shopify
      validate_customer_data!(customer_data)
      validate_no_existing_records!(customer_data)

      ActiveRecord::Base.transaction do
        company_data = extract_company_data(customer_data)

        organization = Organization.create!(name: company_data[:company_name])
        user = User.create!(
          email: customer_data["email"],
          first_name: customer_data["firstName"],
          last_name: customer_data["lastName"],
          country: country_code,
          organization: organization
        )
        shopify_customer = ShopifyCustomer.create!(
          external_shopify_id: external_shopify_id,
          user: user,
          country_code: country_code
        )
        company = Company.create!(
          company_name: company_data[:company_name],
          shopify_company_id: company_data[:company_id],
          shopify_company_location_id: company_data[:location_id],
          shopify_company_contact_id: company_data[:contact_id]
        )
        shopify_customer.update!(company: company)

        { organization: organization, user: user, shopify_customer: shopify_customer, company: company }
      end
    end

    private

    def fetch_customer_from_shopify
      query = <<~GRAPHQL
        query getCustomerWithCompany($customerId: ID!) {
          customer(id: $customerId) {
            id
            firstName
            lastName
            email
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

      customer_gid = "gid://shopify/Customer/#{external_shopify_id}"
      response = graphql_client.query(query: query, variables: { customerId: customer_gid })

      raise OnboardingError, "Failed to query Shopify API" unless response

      result = response.body

      if result&.dig("errors")
        messages = result["errors"].map { |e| e["message"] }.join(", ")
        raise OnboardingError, "Shopify API returned errors: #{messages}"
      end

      result&.dig("data", "customer")
    end

    def validate_customer_data!(data)
      raise OnboardingError, "Customer not found in Shopify for ID #{external_shopify_id}" unless data
      raise OnboardingError, "Customer is missing an email address in Shopify" unless data["email"].present?
      raise OnboardingError, "Customer is missing a first name in Shopify" unless data["firstName"].present?

      profiles = data["companyContactProfiles"]
      raise OnboardingError, "Customer has no B2B company profile in Shopify" if profiles.nil? || profiles.empty?

      company = profiles.first["company"]
      raise OnboardingError, "Company data is incomplete — missing company name" unless company && company["name"].present?

      locations = company.dig("locations", "edges")
      raise OnboardingError, "Company has no locations in Shopify" unless locations&.any?
    end

    def validate_no_existing_records!(data)
      if User.exists?(email: data["email"])
        raise OnboardingError, "A user with email #{data["email"]} already exists"
      end

      if ShopifyCustomer.exists?(external_shopify_id: external_shopify_id)
        raise OnboardingError, "A Shopify customer with ID #{external_shopify_id} already exists"
      end

      company = data["companyContactProfiles"].first["company"]
      company_name = company["name"]
      shopify_company_id = extract_id_from_gid(company["id"])

      if Organization.exists?(name: company_name)
        raise OnboardingError, "An organization named \"#{company_name}\" already exists"
      end

      if Company.exists?(shopify_company_id: shopify_company_id)
        raise OnboardingError, "A company with Shopify ID #{shopify_company_id} already exists"
      end
    end

    def extract_company_data(customer_data)
      profile = customer_data["companyContactProfiles"].first
      company = profile["company"]
      location = company["locations"]["edges"].first["node"]

      {
        company_name: company["name"],
        company_id: extract_id_from_gid(company["id"]),
        location_id: extract_id_from_gid(location["id"]),
        contact_id: extract_id_from_gid(profile["id"])
      }
    end

    def extract_id_from_gid(gid)
      gid.to_s.split("/").last
    end

    def graphql_client
      @graphql_client ||= begin
        session = ShopifyAPI::Auth::Session.new(
          shop: country_config["shopify_domain"],
          access_token: country_config["shopify_access_token"]
        )
        ShopifyAPI::Clients::Graphql::Admin.new(session: session)
      end
    end
  end
end
