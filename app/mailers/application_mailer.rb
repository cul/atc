# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  # This email will not work with our settings
  default from: 'from@example.com'
  layout 'mailer'
end
