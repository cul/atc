# frozen_string_literal: true

class Atc::Stabilization::BagUploader
  attr_reader :bucket_name

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

  def generate_s3_object(object_key)
    Aws::S3::Object.new(@bucket_name, object_key, { client: @s3_client })
  end
end
