source "https://rubygems.org"

ruby "~>3.2.0"

gem "rails", "~> 7.1.3"
gem "view_component"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "sprockets-rails"
gem "jbuilder"

# Use mysql2 gem for mysql connections
gem 'mysql2', '0.5.4'

# everybody loves rainbows
gem 'rainbow', '~> 3.0'

# Use Puma for local development
gem 'puma', '~> 6.0'

# For retrying code blocks that may return an error
gem 'retriable', '~> 2.1'

gem 'resque'
gem "redis", ">= 4.0.1"
gem "kredis"

gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "bootsnap", require: false

group :development, :test do
  gem "sqlite3"
  # Use Capistrano for deployment
  gem 'capistrano', '~> 3.17.3', require: false
  # Rails and Bundler integrations were moved out from Capistrano 3
  gem 'capistrano-rails', '~> 1.4', require: false
  gem 'capistrano-bundler', '~> 1.1', require: false
  # "idiomatic support for your preferred ruby version manager"
  gem 'capistrano-rvm', '~> 0.1', require: false
  # The `deploy:restart` hook for passenger applications is now in a separate gem
  # Just add it to your Gemfile and require it in your Capfile.
  gem 'capistrano-passenger', '~> 0.2', require: false
  # Use net-ssh >= 4.2 to prevent warnings with Ruby 2.4
  gem 'net-ssh', '>= 4.2'
  gem 'rspec-rails'
  gem 'rspec-json_expectations'
  gem 'capybara', '~> 3.32'
  # For testing with chromedriver for headless-browser JavaScript testing
  gem 'selenium-webdriver', '~> 4.16.0'
  gem 'database_cleaner'
  gem 'factory_bot_rails'
  gem 'rubocop', '~> 0.53.0', require: false
  gem 'rubocop-rspec', '>= 1.20.1', require: false
  gem 'rubocop-rails_config', require: false
  gem 'listen'
end
