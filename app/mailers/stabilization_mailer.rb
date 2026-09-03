# frozen_string_literal: true

class StabilizationMailer < ApplicationMailer
  def send_mail
    mail(
      to: params[:to],
      from: SMB_CONFIG[:default_sender_email_address],
      subject: params[:subject],
      content_type: 'text/plain',
      body: params[:body_content]
    )
  end
end
