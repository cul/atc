# frozen_string_literal: true

class StabilizationMailer < ApplicationMailer
  def self.notify(subject, message)
    with(
      to: STABILIZATION_CONFIG[:notification_email],
      subject: subject,
      body_content: message
    ).send_mail.deliver
  end

  def send_mail
    mail(
      to: params[:to],
      from: STABILIZATION_CONFIG[:default_sender_email_address],
      subject: params[:subject],
      content_type: 'text/plain',
      body: params[:body_content]
    )
  end
end
