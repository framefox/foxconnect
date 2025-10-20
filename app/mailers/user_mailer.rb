class UserMailer < ApplicationMailer
  def welcome_invitation(user, reset_password_token)
    @user = user
    @token = reset_password_token
    @reset_password_url = edit_user_password_url(reset_password_token: @token)

    # Attach logo inline for email
    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    # Use country-specific sender email
    from_email = user_from_email(@user)

    mail(
      to: @user.email,
      from: from_email,
      subject: "Welcome to Framefox Connect - Set Your Password"
    )
  end

  private

  def user_from_email(user)
    return CountryConfig.for_country("NZ")["email_from"] unless user.country.present?

    CountryConfig.for_country(user.country)["email_from"]
  end
end
