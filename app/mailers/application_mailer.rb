class ApplicationMailer < ActionMailer::Base
  default from: -> { format_from_email(CountryConfig.for_country("NZ")["email_from"]) }
  layout "mailer"

  private

  def self.format_from_email(email)
    "Framefox Support <#{email}>"
  end

  def format_from_email(email)
    "Framefox Support <#{email}>"
  end
end
