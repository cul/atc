# frozen_string_literal: true

AWS_CONFIG = Rails.application.config_for(:aws).deep_symbolize_keys

S3_CLIENT = Aws::S3::Client.new(
  region: AWS_CONFIG[:aws_region],
  credentials: Aws::Credentials.new(
    AWS_CONFIG[:aws_access_key_id],
    AWS_CONFIG[:aws_secret_access_key]
  )
)

# Setting this here to satisfy expectation for standalone call to
# Aws::S3::MultipartFileUploader#compute_default_part_size.
ENV['AWS_REGION'] = AWS_CONFIG[:aws_region]

def validate_aws_config!
  # Make sure that any local_path_key_map key ends with a trailing slash.  This is important
  # because a leading slash must be absent from the translated bucket key path.
  AWS_CONFIG[:local_path_key_map].each_key do |key|
    raise "Found invalid key in aws.yml local_path_key_map: #{key} (key must end with a '/')" unless key.end_with?('/')
  end
end

validate_aws_config!
