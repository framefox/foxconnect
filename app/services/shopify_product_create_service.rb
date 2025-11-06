class ShopifyProductCreateService
  attr_reader :store, :session

  def initialize(store)
    @store = store

    # Block creation for inactive stores
    unless store.active?
      raise ShopifyIntegration::InactiveStoreError, "Cannot create products for inactive store: #{store.name}"
    end

    # Block creation for non-Shopify stores
    unless store.shopify?
      raise ArgumentError, "Product creation is only supported for Shopify stores"
    end

    @session = ShopifyAPI::Auth::Session.new(
      shop: store.shopify_domain,
      access_token: store.shopify_token
    )
  end

  def fetch_product(product_id)
    Rails.logger.info "Fetching product #{product_id} from Shopify for store: #{store.name}"

    # Create GraphQL client
    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

    # Build query
    query = build_product_fetch_query
    variables = { id: "gid://shopify/Product/#{product_id}" }

    # Execute query
    response = client.query(query: query, variables: variables)

    # Parse response
    if response.body.dig("data", "product")
      product_data = response.body["data"]["product"]
      
      # Extract options in our format
      product_options = extract_product_options(product_data)
      
      {
        success: true,
        product: {
          id: product_data["id"],
          title: product_data["title"],
          description_html: product_data["descriptionHtml"],
          product_options: product_options
        }
      }
    else
      Rails.logger.error "Failed to fetch product: #{response.body.inspect}"
      {
        success: false,
        errors: ["Product not found"]
      }
    end
  rescue => e
    Rails.logger.error "Exception fetching product: #{e.message}"
    {
      success: false,
      errors: [e.message]
    }
  end

  def create_product(product_data)
    Rails.logger.info "Creating product in Shopify for store: #{store.name}"
    Rails.logger.info "Product title: #{product_data[:title]}"

    # Create GraphQL client
    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

    # Build mutation
    mutation = build_product_create_mutation
    variables = build_variables(product_data)

    Rails.logger.info "Mutation variables: #{variables.to_json}"

    # Execute mutation
    response = client.query(query: mutation, variables: variables)

    # Parse response
    if response.body.dig("data", "productSet", "product")
      product = response.body["data"]["productSet"]["product"]
      user_errors = response.body["data"]["productSet"]["userErrors"]

      if user_errors.any?
        Rails.logger.error "Product created with errors: #{user_errors.inspect}"
        return {
          success: false,
          errors: user_errors.map { |e| e["message"] }
        }
      end

      Rails.logger.info "Product created successfully: #{product['id']}"
      {
        success: true,
        product_id: product["id"],
        product: product
      }
    else
      errors = response.body.dig("data", "productSet", "userErrors") || []
      error_messages = errors.map { |e| e["message"] }
      
      Rails.logger.error "Failed to create product: #{error_messages.join(', ')}"
      Rails.logger.error "Full response: #{response.body.inspect}"
      
      {
        success: false,
        errors: error_messages.presence || ["Unknown error occurred"]
      }
    end
  rescue => e
    Rails.logger.error "Exception creating product: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    {
      success: false,
      errors: [e.message]
    }
  end

  private

  def build_product_fetch_query
    <<~GRAPHQL
      query getProduct($id: ID!) {
        product(id: $id) {
          id
          title
          descriptionHtml
          options {
            id
            name
            position
            values
            optionValues {
              id
              name
            }
          }
        }
      }
    GRAPHQL
  end

  def extract_product_options(product_data)
    return {} unless product_data["options"]&.any?

    options_hash = {}
    product_data["options"].each_with_index do |option, index|
      options_hash[index.to_s] = {
        "name" => option["name"],
        "values" => option["values"] || option["optionValues"]&.map { |ov| ov["name"] } || []
      }
    end
    
    options_hash
  end

  def build_product_create_mutation
    <<~GRAPHQL
      mutation productSet($input: ProductSetInput!, $synchronous: Boolean!) {
        productSet(input: $input, synchronous: $synchronous) {
          product {
            id
            title
            handle
            status
            variants(first: 100) {
              edges {
                node {
                  id
                  title
                  inventoryQuantity
                }
              }
            }
          }
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL
  end

  def build_variables(product_data)
    product_input = {
      title: product_data[:title],
      status: "DRAFT"
    }

    # Add description if provided
    if product_data[:description_html].present?
      product_input[:descriptionHtml] = product_data[:description_html]
    end

    # Build product options and variants
    if product_data[:product_options].present?
      # Convert ActionController::Parameters to hash, then to array
      options_hash = product_data[:product_options].to_h
      options_array = options_hash.values
      
      Rails.logger.info "Options array: #{options_array.inspect}"
      
      # Filter out options without name or values
      options = options_array.select do |opt|
        next false unless opt.is_a?(Hash)
        
        name = opt["name"] || opt[:name]
        values = opt["values"] || opt[:values]
        
        name.present? && values.present?
      end
      
      Rails.logger.info "Filtered options: #{options.inspect}"
      
      if options.any?
        # Add product options
        product_input[:productOptions] = options.map do |option|
          name = option["name"] || option[:name]
          values = option["values"] || option[:values]
          
          {
            name: name,
            values: values.select(&:present?).map { |value| { name: value } }
          }
        end
        
        # Generate all variant combinations
        product_input[:variants] = generate_variant_combinations(options)
      end
    end

    {
      input: product_input,
      synchronous: true
    }
  end

  def generate_variant_combinations(options)
    # Extract option names and their values
    option_data = options.map do |opt|
      name = opt["name"] || opt[:name]
      values = opt["values"] || opt[:values]
      values = values.select(&:present?)
      { name: name, values: values }
    end

    # Generate all combinations
    if option_data.length == 1
      # Single option
      option_data[0][:values].map do |value|
        {
          optionValues: [
            { optionName: option_data[0][:name], name: value }
          ]
        }
      end
    elsif option_data.length == 2
      # Two options
      combinations = []
      option_data[0][:values].each do |val1|
        option_data[1][:values].each do |val2|
          combinations << {
            optionValues: [
              { optionName: option_data[0][:name], name: val1 },
              { optionName: option_data[1][:name], name: val2 }
            ]
          }
        end
      end
      combinations
    elsif option_data.length == 3
      # Three options
      combinations = []
      option_data[0][:values].each do |val1|
        option_data[1][:values].each do |val2|
          option_data[2][:values].each do |val3|
            combinations << {
              optionValues: [
                { optionName: option_data[0][:name], name: val1 },
                { optionName: option_data[1][:name], name: val2 },
                { optionName: option_data[2][:name], name: val3 }
              ]
            }
          end
        end
      end
      combinations
    else
      []
    end
  end
end

