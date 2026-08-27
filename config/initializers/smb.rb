# frozen_string_literal: true

SMB_CONFIG = Rails.application.config_for(:smb).deep_symbolize_keys

# TODO: Error handling
FileUtils.mkdir_p(SMB_CONFIG[:stabilization_dir])
