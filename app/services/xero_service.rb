class XeroService
  TOKEN_URL = "https://identity.xero.com/connect/token"
  CONNECTIONS_URL = "https://api.xero.com/connections"
  INVOICES_URL = "https://api.xro/2.0/Invoices"
  BASE_URL = "https://api.xero.com/api.xro/2.0"

  class XeroError < StandardError; end

  def initialize(country_code)
    @config = CountryConfig.for_country(country_code)
    @client_id = @config["xero_client_id"]
    @client_secret = @config["xero_client_secret"]
    @tax_type = @config["xero_tax_type"]
    @account_code = @config["xero_account_code"]

    raise XeroError, "Missing Xero credentials for #{country_code}" if @client_id.blank? || @client_secret.blank?
  end

  def create_draft_invoice(contact_id:, line_items:, date:, due_date: nil, reference: nil)
    authenticate!

    payload = {
      Type: "ACCREC",
      Contact: { ContactID: contact_id },
      LineAmountTypes: "Inclusive",
      LineItems: line_items.map { |li|
        {
          Description: li[:description],
          Quantity: li[:quantity],
          UnitAmount: li[:unit_amount],
          AccountCode: @account_code,
          TaxType: @tax_type
        }
      },
      Status: "DRAFT",
      Date: date.iso8601,
      DueDate: due_date&.iso8601,
      Reference: reference
    }.compact

    response = HTTP.auth("Bearer #{@access_token}")
      .headers("Xero-Tenant-Id" => @tenant_id, "Content-Type" => "application/json")
      .put("#{BASE_URL}/Invoices", json: payload)

    unless response.status.success?
      raise XeroError, "Failed to create invoice: #{response.status} - #{response.body}"
    end

    result = response.parse
    invoice = result["Invoices"]&.first

    raise XeroError, "No invoice returned from Xero" unless invoice

    {
      invoice_id: invoice["InvoiceID"],
      invoice_number: invoice["InvoiceNumber"],
      invoice_url: "https://go.xero.com/AccountsReceivable/View.aspx?InvoiceID=#{invoice['InvoiceID']}"
    }
  end

  private

  def authenticate!
    token_response = HTTP.basic_auth(user: @client_id, pass: @client_secret)
      .post(TOKEN_URL, form: { grant_type: "client_credentials" })

    unless token_response.status.success?
      raise XeroError, "Failed to authenticate with Xero: #{token_response.status} - #{token_response.body}"
    end

    token_data = token_response.parse
    @access_token = token_data["access_token"]

    connections_response = HTTP.auth("Bearer #{@access_token}").get(CONNECTIONS_URL)

    unless connections_response.status.success?
      raise XeroError, "Failed to get Xero connections: #{connections_response.status}"
    end

    connections = connections_response.parse
    raise XeroError, "No Xero connections found" if connections.empty?

    @tenant_id = connections.first["tenantId"]
  end
end
