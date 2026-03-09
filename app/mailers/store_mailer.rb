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

  # Sends a daily reminder to organization users about orders still in draft status.
  # Use with: StoreMailer.with(organization: org, orders: orders).draft_orders_reminder.deliver_later
  def draft_orders_reminder
    @organization = params[:organization]
    @orders = params[:orders]

    recipients = @organization.users.where.not(email: [nil, ""]).pluck(:email)
    return if recipients.empty?

    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    first_user = @organization.users.first
    from_email = format_from_email(user_from_email(first_user))

    mail(
      to: recipients,
      from: from_email,
      subject: "You have #{@orders.size} #{'order'.pluralize(@orders.size)} requiring your attention"
    )
  end

  private

  def user_from_email(user)
    CountryConfig.for_country(user.country)["email_from"]
  end
end

