# frozen_string_literal: true

AWS_CONFIG = Rails.application.config_for(:aws).deep_symbolize_keys

S3_CLIENT = Aws::S3::Client.new(
  region: AWS_CONFIG[:aws_region],
  credentials: Aws::Credentials.new(
    AWS_CONFIG[:aws_access_key_id],
    AWS_CONFIG[:aws_secret_access_key],
    AWS_CONFIG[:aws_session_token]
  )
)

# Setting this here to satisfy expectation for standalone call to
# Aws::S3::MultipartFileUploader#compute_default_part_size.
ENV['AWS_REGION'] = AWS_CONFIG[:aws_region]

def validate_aws_config!
  csv_exports_directory = AWS_CONFIG[:s3_browser][:csv_exports_directory]

  if csv_exports_directory.blank?
    logger.error('CSV export directory is not configured in aws.yml')
    raise 'CSV export directory is not configured in aws.yml'
  end

  FileUtils.mkdir_p(csv_exports_directory)
end

validate_aws_config!
