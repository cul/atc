# frozen_string_literal: true

require 'aws-sdk-s3'
require 'fileutils'

class Atc::Aws::S3Downloader
  def initialize(bucket_name, download_directory, s3_client = S3_CLIENT)
    @s3_client = s3_client
    @bucket_name = bucket_name
    @download_directory = download_directory
    # @transfer_manager = Aws::S3::TransferManager.new(client: @s3_client)
  end

  def download_directory(s3_folder_prefix)
    local_destination = @download_directory

    # Ensure the local base directory exists
    FileUtils.mkdir_p(local_destination)

    puts "Downloading data from s3://#{@bucket_name}/#{s3_folder_prefix} to the local directory #{@download_directory}"
    nil

    # @transfer_manager.download_directory(
    #   @download_directory,
    #   bucket: @bucket_name,
    #   s3_prefix: s3_folder_prefix
    # )
  end
end
