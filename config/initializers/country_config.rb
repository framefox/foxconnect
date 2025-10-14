module CountryConfig
  CONFIG_PATH = Rails.root.join("config", "countries")

  class << self
    def for_country(country_code)
      return nil if country_code.blank?

      @configs ||= {}
      @configs[country_code.upcase] ||= load_config(country_code.upcase)
    end

    def supported_countries
      [ "NZ", "AU" ]
    end

    def supported?(country_code)
      return false if country_code.blank?
      supported_countries.include?(country_code.to_s.upcase)
    end

    private

    def load_config(country_code)
      file_path = CONFIG_PATH.join("#{country_code.downcase}.yml")
      raise "Country config not found: #{country_code}" unless File.exist?(file_path)

      config = YAML.load(ERB.new(File.read(file_path)).result)
      config[Rails.env.to_s]
    end
  end
end
