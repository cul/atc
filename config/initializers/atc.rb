# frozen_string_literal: true

# Load ATC config
ATC = Rails.application.config_for(:atc).deep_symbolize_keys

# Save app version in APP_VERSION constant
APP_VERSION = File.read(Rails.root.join('VERSION')).strip

Rails.application.config.active_job.queue_adapter = :inline if ATC['run_queued_jobs_inline']

def validate_atc_config!
  ATC[:source_paths_to_storage_providers] ||= {}

  # Ensure that all source_paths_to_storage_providers have an associated path_mapping value.
  # Also ensure that each source_paths_to_storage_providers key end with a trailing slash. This is important
  # because a leading slash must be absent from the translated bucket key path.
  ATC[:source_paths_to_storage_providers].each do |key, config|
    unless key.end_with?('/')
      raise "Found invalid key in atc.yml source_paths_to_storage_providers: #{key} (key must end with a '/')"
    end

    unless config.key?(:path_mapping)
      raise "Missing path_mapping in atc.yml source_paths_to_storage_providers for key: #{key}"
    end
  end
end

validate_atc_config!
