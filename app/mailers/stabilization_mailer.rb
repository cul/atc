# frozen_string_literal: true

class StabilizationMailer < ApplicationMailer
  def send_mail
    mail(
      to: params[:to],
      subject: params[:subject],
      content_type: 'text/plain',
      body: params[:body_content]
    )
  end
end
