# frozen_string_literal: true

CHECK_PLEASE = Rails.application.config_for(:check_please)

def validate_check_please_config!
  missing_options = [:http_base_url, :ws_url, :auth_token, :http_timeout].reject do |required_config_option|
    CHECK_PLEASE.key?(required_config_option)
  end
  raise "Missing required check_please.yml options: #{missing_options.inspect}" if missing_options.present?
end

validate_check_please_config!
