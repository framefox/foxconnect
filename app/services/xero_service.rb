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

  def create_invoice(contact_id:, line_items:, date:, due_date: nil, reference: nil, status: "DRAFT", currency: nil, idempotency_key: nil)
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
          AccountCode: li[:account_code] || @account_code,
          TaxType: @tax_type
        }
      },
      Status: status,
      Date: date.iso8601,
      DueDate: due_date&.iso8601,
      CurrencyCode: currency,
      Reference: reference
    }.compact

    headers = {
      "Xero-Tenant-Id" => @tenant_id,
      "Content-Type" => "application/json"
    }
    headers["Idempotency-Key"] = idempotency_key if idempotency_key.present?

    response = HTTP.auth("Bearer #{@access_token}")
      .headers(headers)
      .put("#{BASE_URL}/Invoices", json: payload)

    unless response.status.success?
      raise XeroError, "Failed to create invoice: #{response.status} - #{response.body}"
    end

    result = response.parse
    invoice = result["Invoices"]&.first

    raise XeroError, "No invoice returned from Xero" unless invoice

    invoice_id = invoice["InvoiceID"]

    {
      invoice_id: invoice_id,
      invoice_number: invoice["InvoiceNumber"],
      invoice_url: "https://go.xero.com/AccountsReceivable/View.aspx?InvoiceID=#{invoice_id}",
      online_invoice_url: online_invoice_url_or_nil(invoice_id, status)
    }
  end

  # Fetches the public "online invoice" link (https://in.xero.com/...) that
  # customers can open without a Xero login. Only available once the invoice is
  # AUTHORISED. Returns nil if Xero has not generated one.
  def get_online_invoice_url(invoice_id)
    authenticate! unless @access_token

    response = HTTP.auth("Bearer #{@access_token}")
      .headers("Xero-Tenant-Id" => @tenant_id, "Content-Type" => "application/json")
      .get("#{BASE_URL}/Invoices/#{invoice_id}/OnlineInvoice")

    unless response.status.success?
      raise XeroError, "Failed to get online invoice URL for #{invoice_id}: #{response.status} - #{response.body}"
    end

    online_invoice = response.parse["OnlineInvoices"]&.first
    online_invoice&.dig("OnlineInvoiceUrl").presence
  end

  def create_draft_invoice(contact_id:, line_items:, date:, due_date: nil, reference: nil)
    create_invoice(
      contact_id: contact_id,
      line_items: line_items,
      date: date,
      due_date: due_date,
      reference: reference,
      status: "DRAFT"
    )
  end

  def approve_invoice(invoice_id)
    authenticate! unless @access_token

    payload = {
      InvoiceID: invoice_id,
      Status: "AUTHORISED"
    }

    response = HTTP.auth("Bearer #{@access_token}")
      .headers("Xero-Tenant-Id" => @tenant_id, "Content-Type" => "application/json")
      .post("#{BASE_URL}/Invoices/#{invoice_id}", json: payload)

    unless response.status.success?
      raise XeroError, "Failed to approve invoice #{invoice_id}: #{response.status} - #{response.body}"
    end

    true
  end

  def email_invoice(invoice_id)
    authenticate! unless @access_token

    response = HTTP.auth("Bearer #{@access_token}")
      .headers("Xero-Tenant-Id" => @tenant_id, "Content-Type" => "application/json")
      .post("#{BASE_URL}/Invoices/#{invoice_id}/Email")

    unless response.status.success?
      raise XeroError, "Failed to email invoice #{invoice_id}: #{response.status} - #{response.body}"
    end

    true
  end

  private

  # Best-effort fetch of the public online invoice URL. Only AUTHORISED invoices
  # have one, and a fetch failure must never block invoice creation.
  def online_invoice_url_or_nil(invoice_id, status)
    return nil unless status == "AUTHORISED"

    get_online_invoice_url(invoice_id)
  rescue XeroError => e
    Rails.logger.warn "XeroService: could not fetch online invoice URL for #{invoice_id}: #{e.message}"
    nil
  end

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
