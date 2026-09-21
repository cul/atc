# frozen_string_literal: true

class Atc::Stabilization::BagUploader
  attr_reader :bucket_name

  def initialize(bucket_name, s3_client = S3_CLIENT)
    @bucket_name = bucket_name
    @s3_client = s3_client
    @transfer_manager = Aws::S3::TransferManager.new(client: @s3_client)
  end

  def upload_file(local_file_path, object_key)
    @transfer_manager.upload_file(
      local_file_path,
      bucket: @bucket_name,
      key: object_key,
      checksum_algorithm: 'CRC32C',
      content_type: BestType.mime_type.for_file_name(local_file_path)
    )
  end

  def directory_exists(directory_path)
    # A directory exists if at least one object shares its prefix
    prefix = directory_path.end_with?('/') ? directory_path : "#{directory_path}/"

    response = @s3_client.list_objects_v2(bucket: @bucket_name, prefix: prefix, max_keys: 1)
    directory_exists = response.key_count.positive?

    if directory_exists
      Rails.logger.error("The directory '#{prefix}' exists (or contains files).")
    else
      Rails.logger.info("The directory '#{prefix}' does not exist or is empty.")
    end

    directory_exists
  end
end
