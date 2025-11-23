class StoreMailer < ApplicationMailer
  # Sends an email to the store owner when reauthentication is required
  # Use with: StoreMailer.with(store: store).reauthentication_required.deliver_later
  def reauthentication_required
    @store = params[:store]
    @user = @store.user

    return if @user.blank? || @user.email.blank?

    # Attach logo inline for email
    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    # Use country-specific sender email
    from_email = format_from_email(user_from_email(@user))

    mail(
      to: @user.email,
      from: from_email,
      subject: "Action Required: Reconnect Your #{@store.platform.titleize} Store - #{@store.name}"
    )
  end

  private

  def user_from_email(user)
    CountryConfig.for_country(user.country)["email_from"]
  end
end

