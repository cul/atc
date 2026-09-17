# frozen_string_literal: true

STABILIZATION_CONFIG = Rails.application.config_for(:stabilization).deep_symbolize_keys
SMB_CREDENTIAL_KEYS = %i[username password domain].freeze

# Writes the auth file that smbclient uses for authentication
def write_smb_auth_file!
  credentials = STABILIZATION_CONFIG.dig(:sources, :ldrive) || {}
  missing = SMB_CREDENTIAL_KEYS.select { |key| credentials[key].blank? }

  if missing.any?
    raise "stabilization.yml is missing the following keys under sources -> ldrive -> #{missing.join(', ')}"
  end

  File.write(
    Atc::Smb::Connector.auth_file_path,
    "username=#{credentials[:username]}\npassword=#{credentials[:password]}\ndomain=#{credentials[:domain]}\n"
  )
end

Rails.application.config.after_initialize do
  raise 'stabilization.yml is missing work_dir' if STABILIZATION_CONFIG[:work_dir].blank?

  FileUtils.mkdir_p(STABILIZATION_CONFIG[:work_dir])
  write_smb_auth_file!
end
