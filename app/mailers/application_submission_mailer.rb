class ApplicationSubmissionMailer < ApplicationMailer
  def new_application(params)
    @params = params

    # Determine recipient email based on country
    recipient_email = case params[:country]
    when "New Zealand"
      "frames@framefox.co.nz"
    when "Australia"
      "frames@framefox.com.au"
    else
      "frames@framefox.co.nz"
    end

    mail(
      to: recipient_email,
      subject: "New Framefox Connect Application - #{params[:name]}"
    )
  end
end

