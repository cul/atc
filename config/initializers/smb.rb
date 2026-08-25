# frozen_string_literal: true

SMB_CONFIG = Rails.application.config_for(:smb).deep_symbolize_keys

Rails.logger.debug("SMB Username: #{SMB_CONFIG[:username]}")
Rails.logger.debug("SMB Password: #{SMB_CONFIG[:password]}")
Rails.logger.debug("SMB Domain: #{SMB_CONFIG[:domain]}")
