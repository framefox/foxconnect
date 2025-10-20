class UserMailer < ApplicationMailer
  def welcome_invitation(user, reset_password_token)
    @user = user
    @token = reset_password_token
    @reset_password_url = edit_user_password_url(reset_password_token: @token)

    # Attach logo inline for email
    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    mail(
      to: @user.email,
      subject: "Welcome to Framefox Connect - Set Your Password"
    )
  end
end
