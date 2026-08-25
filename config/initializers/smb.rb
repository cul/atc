# frozen_string_literal: true

SMB_CONFIG = Rails.application.config_for(:smb).deep_symbolize_keys

Rails.logger.info("SMB Username: #{SMB_CONFIG[:username]}")
Rails.logger.info("SMB Password: #{SMB_CONFIG[:password]}")
Rails.logger.info("SMB Domain: #{SMB_CONFIG[:domain]}")
