# frozen_string_literal: true

require 'aws-sdk-s3'

class Atc::Aws::S3Remover
  def initialize(bucket_name, s3_client = S3_CLIENT)
    @s3_client = s3_client
    @bucket_name = bucket_name
    @bucket = Aws::S3::Resource.new(client: @s3_client).bucket(@bucket_name)
  end

  # AWS doesn't have a concept of a directory, we need to remove all objects that share the prefix
  def delete_directory(s3_folder_prefix)
    # Ensure a trailing slash so we don't delete objects from folders that start
    # with the same prefix
    s3_folder_prefix = "#{s3_folder_prefix.chomp('/')}/"

    Rails.logger.info("Deleting all objects under s3://#{@bucket_name}/#{s3_folder_prefix}")

    objects_to_delete = @bucket.objects(prefix: s3_folder_prefix)

    deleted_count = objects_to_delete.count

    if deleted_count.zero?
      Rails.logger.info("No objects found with prefix '#{s3_folder_prefix}'")
    else
      objects_to_delete.batch_delete!
      Rails.logger.info("Deleted #{deleted_count} object(s) with prefix '#{s3_folder_prefix}'")
    end
  end
end
