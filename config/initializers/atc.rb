# frozen_string_literal: true

# Load Triclops config
ATC = Rails.application.config_for(:atc).deep_symbolize_keys

Rails.application.config.active_job.queue_adapter = :inline if ATC['run_queued_jobs_inline']
