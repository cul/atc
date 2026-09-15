# frozen_string_literal: true

STABILIZATION_CONFIG = Rails.application.config_for(:stabilization).deep_symbolize_keys

Rails.application.config.after_initialize do
  FileUtils.mkdir_p(STABILIZATION_CONFIG[:work_dir])

  # TODO: Error handling
  credentials = STABILIZATION_CONFIG[:sources][:ldrive]
  File.write(
    Atc::Smb::Connector.auth_file_path,
    "username=#{credentials[:username]}\npassword=#{credentials[:password]}\ndomain=#{credentials[:domain]}\n"
  )
rescue StandardError => e
  Rails.logger.error("Error setting up SMB auth file: #{e.message}")
end
