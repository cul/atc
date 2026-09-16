# frozen_string_literal: true

class Atc::Stabilization::BagUploader
  attr_reader :bucket_name

  def initialize(bucket_name, s3_client = S3_CLIENT)
    @bucket_name = bucket_name
    @s3_client = s3_client
    @transfer_manager = Aws::S3::TransferManager.new(client: @s3_client)
  end

  def upload_file(local_file_path, object_key)
    # The same threshold must be used for both the checksum and the upload
    multipart_threshold = Atc::Constants::DEFAULT_MULTIPART_THRESHOLD
    expected_crc32c = Atc::Utils::AwsChecksumUtils.checksum_string_for_file(
      local_file_path, multipart_threshold
    )

    @transfer_manager.upload_file(
      local_file_path,
      bucket: @bucket_name,
      key: object_key,
      checksum_algorithm: 'CRC32C',
      multipart_threshold: multipart_threshold,
      content_type: BestType.mime_type.for_file_name(local_file_path)
    ) do |response|
      verify_aws_response_checksum!(response.checksum_crc32c, expected_crc32c, object_key)
    end
  end

  def directory_exists(directory_path)
    # A directory exists if at least one object shares its prefix
    prefix = directory_path.end_with?('/') ? directory_path : "#{directory_path}/"
    puts "Check if directory exists under s3://#{@bucket_name}/#{prefix}"

    response = @s3_client.list_objects_v2(bucket: @bucket_name, prefix: prefix, max_keys: 1)
    directory_exists = response.key_count.positive?

    if directory_exists
      puts "The directory '#{prefix}' exists (or contains files)."
    else
      puts "The directory '#{prefix}' does not exist or is empty."
    end

    directory_exists
  end

  private

  # Compares the checksum that S3 reports after the upload against one we calculated locally
  def verify_aws_response_checksum!(aws_reported_checksum, expected_crc32c, object_key)
    if aws_reported_checksum.blank?
      raise Atc::Exceptions::TransferError,
            "Expected a CRC32C checksum from S3 after uploading #{object_key}, but it was missing."
    end

    return if aws_reported_checksum == expected_crc32c

    raise Atc::Exceptions::TransferError,
          "CRC32C checksum mismatch for #{object_key}. S3 reported #{aws_reported_checksum}, "\
          "but we calculated #{expected_crc32c}. This requires manual investigation."
  end
end
