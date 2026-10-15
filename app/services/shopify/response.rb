module Shopify
  module Response
    class Error < StandardError; end

    def self.data!(response, field)
      body = response&.body || {}
      errors = Array(body["errors"]) + Array(body.dig("data", field, "userErrors"))
      raise Error, errors.map { |error| error["message"] }.join(", ") if errors.any?

      body.dig("data", field) || raise(Error, "Shopify returned no #{field} data")
    end
  end
end
