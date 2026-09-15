# frozen_string_literal: true

SMB_CONFIG = Rails.application.config_for(:smb).deep_symbolize_keys

Rails.application.config.after_initialize do
  FileUtils.mkdir_p(SMB_CONFIG[:work_dir])

  # TODO: Error handling
  credentials = SMB_CONFIG[:sources][:ldrive]
  File.write(
    Atc::Smb::Connector.auth_file_path,
    "username=#{credentials[:username]}\npassword=#{credentials[:password]}\ndomain=#{credentials[:domain]}\n"
  )
rescue StandardError => e
  Rails.logger.error("Error setting up SMB auth file: #{e.message}")
end
