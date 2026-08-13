# frozen_string_literal: true

# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

require File.expand_path('../config/environment', __dir__)

set :environment, Rails.env

# Log cron output to app log directory
set :output, Rails.root.join("log/#{Rails.env}_cron_log.log")

job_type :rake, 'cd :path && :environment_variable=:environment bundle exec rake :task --silent :output'

if Rails.env.atc_prod? # rubocop:disable Rails/UnknownEnv
  every 1.day, at: '7:00 pm' do
    rake 'atc:csv_exports:delete_expired'
  end
end
