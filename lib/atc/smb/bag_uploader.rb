# frozen_string_literal: true

class Atc::Smb::BagUploader
  def initialize(bucket_name, s3_client = S3_CLIENT)
    @bucket_name = bucket_name
    @s3_client = s3_client
  end

  def upload_file(local_file_path, object_key)
    test = generate_s3_object(object_key).upload_file(
      local_file_path,
      checksum_algorithm: 'CRC32C',
      multipart_threshold: Atc::Constants::DEFAULT_MULTIPART_THRESHOLD,
      content_type: BestType.mime_type.for_file_name(local_file_path)
    )
    puts "Upload result: #{test}"
  end

  private

  def generate_s3_object(object_key)
    Aws::S3::Object.new(@bucket_name, object_key, { client: @s3_client })
  end
end
