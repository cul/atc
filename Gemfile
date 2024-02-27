# frozen_string_literal: true

source 'https://rubygems.org'

# Amazon S3 SDK
gem 'aws-sdk-s3', '~> 1'
# Additional gem enabling the AWS SDK to calculate CRC32C checksums
gem 'aws-crt', '~> 0.2.0'
# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false
# Add CRC32C support to the Ruby Digest module
gem 'digest-crc', '~> 0.6.5'
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'
# Use mysql as a database option for Active Record
gem 'mysql2', '~> 0.5.6'
# Use the Puma web server for local development [https://github.com/puma/puma]
gem 'puma', '~> 6.0'
# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 7.1.3', '>= 7.1.3.2'
# Rainbow for text coloring
gem 'rainbow', '~> 3.0'
# Use Redis adapter to run Action Cable in production
gem 'redis', '>= 4.0.1'
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'
# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[windows jruby]

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri windows]
  # Use sqlite3 as the database for Active Record
  gem 'sqlite3', '~> 1.4'
  # Rubocul for linting
  gem 'rubocul', '~> 4.0.9'
  # gem 'rubocul', path: '../rubocul'
end

group :development do
  # Use Capistrano for deployment
  gem 'capistrano', '~> 3.17.3', require: false
  gem 'capistrano-bundler', '~> 1.1', require: false
  # The `deploy:restart` hook for passenger applications is now in a separate gem
  # Just add it to your Gemfile and require it in your Capfile.
  gem 'capistrano-passenger', '~> 0.2', require: false
  # Rails and Bundler integrations were moved out from Capistrano 3
  gem 'capistrano-rails', '~> 1.4', require: false
  gem 'capistrano-rvm', '~> 0.1', require: false

  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'selenium-webdriver'
end
