require Rails.root.join('config/environments/deployed.rb')

Rails.application.configure do
  config.log_level = :debug

  # Setting host so that url helpers can be used in mailer views.
  config.action_mailer.default_url_options = { host: 'https://atc-dev.library.columbia.edu' }
end
