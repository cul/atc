# frozen_string_literal: true

# Load ATC config
ATC = Rails.application.config_for(:atc).deep_symbolize_keys

# Save app version in APP_VERSION constant
APP_VERSION = File.read(Rails.root.join('VERSION')).strip

Rails.application.config.active_job.queue_adapter = :inline if ATC['run_queued_jobs_inline']
