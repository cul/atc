# frozen_string_literal: true
require "google/cloud/storage"

GCP_CONFIG = Rails.application.config_for(:gcp).deep_symbolize_keys

def validate_gcp_config!
  GCP_CONFIG[:local_path_key_map] ||= {}

  # Make sure that any local_path_key_map key ends with a trailing slash.  This is important
  # because a leading slash must be absent from the translated bucket key path.
  GCP_CONFIG[:local_path_key_map].each_key do |key|
    raise "Found invalid key in gcp.yml local_path_key_map: #{key} (key must end with a '/')" unless key.end_with?('/')
  end
end

validate_gcp_config!

class GcpMockCredentials < Google::Auth::Credentials
    def initialize config, options = {}
      verify_keyfile_provided! config
      options = symbolize_hash_keys options
      @project_id = options[:project_id] || options[:project]
      @quota_project_id = options[:quota_project_id]
      update_from_hash config, options
      @project_id ||= CredentialsLoader.load_gcloud_project_id
      @env_vars = nil
      @paths = nil
      @scope = nil
      @token_credential_uri = config[:token_uri]
      @client_email = config[:client_email]
    end

    def init_client hash, options = {}
      options = update_client_options options
      io = StringIO.new JSON.generate hash
      options.merge! json_key_io: io
      Google::Auth::ServiceAccountCredentials.new(
        token_credential_uri:   @token_credential_uri,
        audience:               @token_credential_uri,
        scope:                  @scope,
        enable_self_signed_jwt: false,
        target_audience:        nil,
        issuer:                 @client_email,
        project_id:             project_id,
        quota_project_id:       quota_project_id,
        universe_domain:        "googleapis.com"
      )
    end
end

GCP_CLIENT = Google::Cloud::Storage.new(
  project_id: GCP_CONFIG[:project_id],
  credentials: GCP_CONFIG[:mock_credentials] ? GcpMockCredentials.new(GCP_CONFIG[:credentials]) : GCP_CONFIG[:credentials]
)
