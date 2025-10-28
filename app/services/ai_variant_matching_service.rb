require "openai"

class AiVariantMatchingService
  def initialize(product:, reference_mapping:, user:, store: nil)
    @product = product
    @reference_mapping = reference_mapping
    @user = user
    @store = store
    @country_code = user.country
    @openai_client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    @reference_descriptors = {} # Store descriptive strings from reference product
  end

  def call
    Rails.logger.info("=" * 80)
    Rails.logger.info("AI Variant Matching Service - Starting")
    Rails.logger.info("Product: #{@product.title} (ID: #{@product.id})")
    Rails.logger.info("User Country: #{@country_code}")
    Rails.logger.info("Reference Mapping: #{@reference_mapping.frame_sku_description}")

    # Get all variants without a mapping for the user's country
    unmapped_variants = get_unmapped_variants
    Rails.logger.info("Unmapped variants count: #{unmapped_variants.count}")
    unmapped_variants.each do |variant|
      Rails.logger.info("  - #{variant.title} (ID: #{variant.id})")
    end

    return { success: false, error: "No unmapped variants found" } if unmapped_variants.empty?

    # Get the API URL based on user's country
    api_url = get_api_url
  Rails.logger.info("API URL: #{api_url}")

    # Fetch available options from the LLM index endpoint
    options_data = fetch_llm_options(api_url)

    return { success: false, error: "Failed to fetch frame SKU options" } unless options_data

    # Extract consistent parameters from reference mapping by fetching its frame SKU details
    Rails.logger.info("=" * 80)
    Rails.logger.info("EXTRACTING CONSISTENT PARAMS FROM REFERENCE MAPPING")
    Rails.logger.info("Reference mapping frame_sku_id: #{@reference_mapping.frame_sku_id}")
    consistent_params = extract_consistent_params(api_url)
    Rails.logger.info("CONSISTENT PARAMS RESULT: #{consistent_params.inspect}")
    Rails.logger.info("=" * 80)

    # Process each unmapped variant
    suggestions = []
    skipped_variants = []
    unmapped_variants.each_with_index do |variant, index|
      Rails.logger.info("-" * 80)
      Rails.logger.info("Processing variant #{index + 1}/#{unmapped_variants.count}: #{variant.title}")
      result = process_variant(variant, options_data, consistent_params, api_url)
      if result[:suggestion]
        Rails.logger.info("✓ Match found for #{variant.title}")
        suggestions << result[:suggestion]
      else
        Rails.logger.warn("✗ No confident match for #{variant.title}")
        skipped_variants << {
          variant_id: variant.id,
          variant_title: variant.title,
          reason: result[:reason],
          ai_response: result[:ai_response]
        }
      end
    end

    Rails.logger.info("=" * 80)
    Rails.logger.info("AI Variant Matching Complete")
    Rails.logger.info("Total unmapped: #{unmapped_variants.count}, Matched: #{suggestions.count}, Skipped: #{unmapped_variants.count - suggestions.count}")
    Rails.logger.info("=" * 80)

    {
      success: true,
      suggestions: suggestions,
      skipped_variants: skipped_variants,
      reference_image_filename: @reference_mapping.image_filename,
      unmapped_count: unmapped_variants.count,
      matched_count: suggestions.count,
      skipped_count: skipped_variants.count
    }
  rescue => e
    Rails.logger.error("AI Variant Matching Error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    { success: false, error: e.message }
  end

  private

  def get_unmapped_variants
    # Only exclude variants that have a DEFAULT mapping for this country
    # Non-default mappings (e.g., from deleted orders) should be ignored
    @product.product_variants.where.not(
      id: VariantMapping.where(
        product_variant_id: @product.product_variants.pluck(:id),
        country_code: @country_code,
        is_default: true
      ).select(:product_variant_id)
    )
  end

  def get_api_url
    # Use the same logic as the frontend ProductSelectionStep
    country_urls = {
      "NZ" => "http://dev.framefox.co.nz:3001/api",
      "AU" => "http://dev.framefox.com.au:3001/api"
    }
    country_urls[@country_code] || country_urls["NZ"]
  end

  def fetch_llm_options(api_url)
    url = "#{api_url}/frame_skus/llm_index.json"
    Rails.logger.info("Fetching LLM options from: #{url}")

    response = HTTP.get(url)
    Rails.logger.info("LLM options response status: #{response.status}")

    return nil unless response.status.success?

    data = JSON.parse(response.body.to_s)
    Rails.logger.info("LLM options received:")
    Rails.logger.info("  - mat_styles: #{data['mat_styles']&.count || 0}")
    Rails.logger.info("  - glass_types: #{data['glass_types']&.count || 0}")
    Rails.logger.info("  - paper_types: #{data['paper_types']&.count || 0}")
    Rails.logger.info("  - frame_style_colours: #{data['frame_style_colours']&.count || 0}")
    Rails.logger.info("  - frame_sku_sizes: #{data['frame_sku_sizes']&.count || 0}")

    data
  rescue => e
    Rails.logger.error("Failed to fetch LLM options: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end

  def extract_consistent_params(api_url)
    # Extract the IDs from reference mapping by fetching the frame SKU details from the API
    # We'll keep mat_style, glass_type, and paper_type consistent across all variants
    params = {}

    if @reference_mapping.frame_sku_id.blank?
      Rails.logger.warn("Reference mapping has no frame_sku_id, cannot extract consistent params")
      return params
    end

    Rails.logger.info("Fetching frame SKU details for reference mapping (frame_sku_id: #{@reference_mapping.frame_sku_id})")

    # Fetch the frame SKU details from the API
    url = "#{api_url}/frame_skus/#{@reference_mapping.frame_sku_id}.json"
    Rails.logger.info("Fetching: #{url}")

    begin
      response = HTTP.get(url)

      unless response.status.success?
        Rails.logger.error("Failed to fetch reference frame SKU: #{response.status}")
        return params
      end

      data = JSON.parse(response.body.to_s)
      # The API wraps the frame_sku in a frame_sku key
      frame_sku = data["frame_sku"]

      unless frame_sku
        Rails.logger.error("No frame_sku data in response: #{data.inspect}")
        return params
      end

      Rails.logger.info("Reference frame SKU fetched: #{frame_sku['code']}")

      # Extract the IDs we need to keep consistent
      if frame_sku["mat_style_id"].present?
        params[:mat_style_id] = frame_sku["mat_style_id"]
        Rails.logger.info("  - mat_style_id: #{params[:mat_style_id]}")
      end

      if frame_sku["glass_type_id"].present?
        params[:glass_type_id] = frame_sku["glass_type_id"]
        Rails.logger.info("  - glass_type_id: #{params[:glass_type_id]}")
      end

      if frame_sku["paper_type_id"].present?
        params[:paper_type_id] = frame_sku["paper_type_id"]
        Rails.logger.info("  - paper_type_id: #{params[:paper_type_id]}")
      end

      # Extract descriptive strings for LLM context
      @reference_descriptors[:paper_type] = frame_sku["paper_type"] if frame_sku["paper_type"].present?
      @reference_descriptors[:mat_style] = frame_sku["mat_style"] if frame_sku["mat_style"].present?
      @reference_descriptors[:frame_style_colour] = frame_sku["frame_style_colour"] if frame_sku["frame_style_colour"].present?
      @reference_descriptors[:glass_type] = frame_sku["glass_type"] if frame_sku["glass_type"].present?

      Rails.logger.info("Reference descriptors: #{@reference_descriptors.inspect}")
      Rails.logger.info("Consistent params extracted successfully")
    rescue => e
      Rails.logger.error("Failed to fetch reference frame SKU: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    params
  end

  def process_variant(variant, options_data, consistent_params, api_url)
    # Use GPT-4o-mini to determine the frame_sku_size and frame_style_colour for this variant
    ai_params = ask_ai_for_params(variant, options_data)

    unless ai_params && ai_params[:confident]
      Rails.logger.warn("AI not confident for variant: #{variant.title}")
      Rails.logger.warn("AI params: #{ai_params.inspect}")
      return {
        suggestion: nil,
        reason: ai_params ? "AI not confident in match" : "Failed to get AI response",
        ai_response: ai_params
      }
    end

    Rails.logger.info("AI confident match:")
    Rails.logger.info("  - frame_sku_size_id: #{ai_params[:frame_sku_size_id]}")
    Rails.logger.info("  - frame_style_colour_id: #{ai_params[:frame_style_colour_id]}")
    Rails.logger.info("  - reasoning: #{ai_params[:reasoning]}")

    # Merge consistent params with AI-determined params
    Rails.logger.info("Before merge - consistent_params: #{consistent_params.inspect}")
    Rails.logger.info("Before merge - ai_params: {frame_sku_size_id: #{ai_params[:frame_sku_size_id]}, frame_style_colour_id: #{ai_params[:frame_style_colour_id]}}")

    search_params = consistent_params.merge(
      frame_sku_size_id: ai_params[:frame_sku_size_id],
      frame_style_colour_id: ai_params[:frame_style_colour_id]
    )

    Rails.logger.info("After merge - search_params: #{search_params.inspect}")

    # Query the frame SKU API with these parameters
    frame_sku = search_frame_sku(api_url, search_params)

    unless frame_sku
      Rails.logger.warn("No frame SKU found for search params: #{search_params.inspect}")
      return {
        suggestion: nil,
        reason: "No frame SKU matched the AI-suggested parameters",
        ai_response: ai_params
      }
    end

    Rails.logger.info("Frame SKU found: #{frame_sku['title']} (ID: #{frame_sku['id']})")

    # Build suggestion object
    {
      suggestion: {
        variant_id: variant.id,
        variant_title: variant.title,
        frame_sku: frame_sku,
        search_params: search_params,
        ai_reasoning: ai_params[:reasoning]
      },
      reason: nil,
      ai_response: ai_params
    }
  rescue => e
    Rails.logger.error("Failed to process variant #{variant.id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    {
      suggestion: nil,
      reason: "Error: #{e.message}",
      ai_response: nil
    }
  end

  def ask_ai_for_params(variant, options_data)
    prompt = build_ai_prompt(variant, options_data)

    Rails.logger.info("Sending prompt to GPT-4o-mini:")
    Rails.logger.info(prompt)

    response = @openai_client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "You are a helpful assistant that matches product variant names to frame SKU parameters. You must respond with valid JSON only."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.3,
        response_format: { type: "json_object" }
      }
    )

    Rails.logger.info("GPT-4o-mini response received")
    content = response.dig("choices", 0, "message", "content")
    Rails.logger.info("Response content: #{content}")

    result = JSON.parse(content)
    Rails.logger.info("Parsed result: #{result.inspect}")

    {
      confident: result["confident"] == true,
      frame_sku_size_id: result["frame_sku_size_id"],
      frame_style_colour_id: result["frame_style_colour_id"],
      reasoning: result["reasoning"]
    }
  rescue => e
    Rails.logger.error("AI API Error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end

  def build_ai_prompt(variant, options_data)
    # Build reference details string
    reference_details = []
    reference_details << "Paper: #{@reference_descriptors[:paper_type]}" if @reference_descriptors[:paper_type].present?
    reference_details << "Mat: #{@reference_descriptors[:mat_style]}" if @reference_descriptors[:mat_style].present?
    reference_details << "Glass: #{@reference_descriptors[:glass_type]}" if @reference_descriptors[:glass_type].present?

    # Build store-specific prompt section if available
    store_prompt_section = if @store&.ai_mapping_prompt.present?
      "\n      Store-Specific Instructions:\n      #{@store.ai_mapping_prompt}\n"
    else
      ""
    end

    <<~PROMPT
      I need to match a product variant to frame SKU parameters.

      Reference Product Context:
      - Reference frame SKU: #{@reference_mapping.frame_sku_description}
      - These settings will be kept consistent across ALL variants:
        #{reference_details.join("\n        ")}
      - Only the SIZE and FRAME COLOR will vary between variants

      Variant to Match:
      - Title: #{variant.title}
      - Options: #{variant.selected_options.to_json}

      Available Frame Sizes:
      #{options_data["frame_sku_sizes"]&.map { |s| "ID: #{s["id"]}, Title: #{s["title"]}" }&.join("\n")}

      Available Frame Styles/Colours:
      #{options_data["frame_style_colours"]&.map { |f| "ID: #{f["id"]}, Title: #{f["title"]}, Colour: #{f["colour"]}" }&.join("\n")}

      Matching Rules:
      - If the reference Frame Style contains "Slim", "Skinny" or "Wide", prioritize frame styles with those words
      - If the variant contains "Wood", "Natural" or "Oak", these always match to Wood colour frames
      - If the Paper is Canvas, then you must choose frames that include the word "Float" in them.
      - The frame style colour you select MUST match the reference frame style characteristics (e.g., if reference is "Zeppelin Slim", select a "Slim" variant)#{store_prompt_section}
      Task:
      Based on the variant title and options, determine which frame_sku_size_id and frame_style_colour_id best match this variant.

      The variant title usually contains size information (like "A2", "A3", "A4", "12x16", etc.) and color/style information (like "Black", "White", "Oak", "Natural", etc.).

      Important:
      - Only return a match if you are confident (>80% certain)
      - The size should match common print sizes (A2, A3, A4, etc.)
      - The frame style colour must be compatible with the reference product's mat, glass, and paper combination
      - The color/style should match the frame style colour options

      Respond with JSON in this exact format:
      {
        "confident": true or false,
        "frame_sku_size_id": <id> or null,
        "frame_style_colour_id": <id> or null,
        "reasoning": "Brief explanation of your match"
      }
    PROMPT
  end

  def search_frame_sku(api_url, params)
    # Build query parameters (keep _id suffix for API)
    query_params = URI.encode_www_form(params.compact)

    url = "#{api_url}/frame_skus.json?#{query_params}"
    Rails.logger.info("Searching frame SKUs: #{url}")

    response = HTTP.get(url)
    Rails.logger.info("Frame SKU search response status: #{response.status}")

    unless response.status.success?
      Rails.logger.error("Frame SKU search failed with status: #{response.status}")
      return nil
    end

    data = JSON.parse(response.body.to_s)
    frame_skus = data["frame_skus"] || []

    Rails.logger.info("Frame SKUs found: #{frame_skus.count}")
    if frame_skus.any?
      Rails.logger.info("First match: #{frame_skus.first['title']}")
    else
      Rails.logger.warn("No frame SKUs matched the search criteria")
    end

    # Return the first matching frame_sku
    frame_skus.first
  rescue => e
    Rails.logger.error("Failed to search frame SKU: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end
end
