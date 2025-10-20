class ApplicationMailer < ActionMailer::Base
  default from: CountryConfig.for_country("NZ")["email_from"]
  layout "mailer"
end
