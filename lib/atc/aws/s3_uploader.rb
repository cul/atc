# frozen_string_literal: true

class Atc::Aws::S3Uploader
  DEFAULT_MULTIPART_THRESHOLD = 100.megabytes
  PROGRESS_DISPLAY_PROC = proc do |bytes, totals|
    print "\r                                               "
    print "\rProgress: #{(100.0 * bytes.sum / totals.sum).round(2)}% (uploading as #{totals.length} parts)"
  end

  def initialize(s3_client, bucket_name)
    @s3_client = s3_client
    @bucket_name = bucket_name
  end

  # Uploads a file to S3
  # @param options [Hash] A hash of options.
  # @option options [Boolean] :overwrite (boolean)
  #   If an object already exists at the target bucket_key, { overwrite: true } will overwrite it
  #   and { overwrite: false } will raise an exception.
  #   Default value: false
  # @option options [String] :precalculated_aws_crc32c
  #   If this option is provided, the given value will be checked against the crc32c checksum sent
  #   in the AWS response after an upload.  If this option is omitted, an additional
  #   local crc32c checksum will be generated right before the upload occurs.
  # @option options [Boolean] :verbose
  #   If provided, this will print progress messages to stdout (via puts).
  #   Default value: false
  # @option options [Hash] :tags
  #   A Hash of key-value tag pairs
  # @option options [Integer] :multipart_threshold
  #   Any file with a size greater than or equal to this value will be uploaded via multipart upload
  #   instead of single part (PUT) upload.  If provided, this option will override the default
  #   multipart threshold, which is defined in Atc::Aws::S3Uploader::DEFAULT_MULTIPART_THRESHOLD.
  def upload_file(local_file_path, bucket_key, **options)
    s3_object = generate_s3_object(bucket_key)
    verbose = options[:verbose]
    multipart_threshold = options[:multipart_threshold] || DEFAULT_MULTIPART_THRESHOLD

    perform_overwrite_check!(options[:overwrite], s3_object)

    precalculated_aws_crc32c = options[:precalculated_aws_crc32c] ||
                               calculate_aws_crc32c(local_file_path, multipart_threshold, verbose)

    puts 'Performing upload...' if verbose
    s3_object.upload_file(
      local_file_path, s3_object_upload_opts(multipart_threshold, options[:tags])
    ) do |resp|
      verify_aws_response_checksum!(resp.checksum_crc32c, precalculated_aws_crc32c)
    end
    puts "\nUpload complete!" if verbose
  rescue Aws::Errors::ServiceError => e
    wrap_and_re_raise_aws_service_error(e, local_file_path)
  end

  def self.tags_to_query_string(tags)
    tags.map { |key, value| "#{key}=#{Addressable::URI.encode_component(value)}" }.join('&')
  end

  private

  def perform_overwrite_check!(allow_overwrite, s3_object)
    return if allow_overwrite || !s3_object.exists?

    raise Atc::Exceptions::ObjectExists,
          "Cancelling upload because existing object was found (at: #{s3_object.key}). "\
          'If you want to replace the existing object, set option { overwrite: true }'
  end

  def wrap_and_re_raise_aws_service_error(err, local_file_path)
    raise Atc::Exceptions::TransferError,
          "An AWS service error occurred while attempting to upload file #{local_file_path} to "\
          "#{s3_object.key}. Error message: #{err.message}"
  end

  def calculate_aws_crc32c(local_file_path, multipart_threshold, verbose)
    puts 'Calculating precalculated_aws_crc32c because one was not provided...' if verbose
    checksum = Atc::Utils::AwsChecksumUtils.checksum_string_for_file(local_file_path, multipart_threshold)
    puts "Done calculating local crc32c checksum (#{checksum})." if verbose
    checksum
  end

  def generate_s3_object(bucket_key)
    Aws::S3::Object.new(@bucket_name, bucket_key, { client: @s3_client })
  end

  def verify_aws_response_checksum!(aws_reported_checksum, precalculated_aws_crc32c)
    if aws_reported_checksum.present?
      if aws_reported_checksum != precalculated_aws_crc32c
        raise Atc::Exceptions::TransferError,
              'AWS local SDK checksum and remote S3 checksums matched, '\
              'but they did not match our precalculated checksum. '\
              "AWS checksum: #{aws_reported_checksum}, Our local checksum: #{precalculated_aws_crc32c}"
      end
    else
      raise Atc::Exceptions::TransferError,
            'Expected AWS S3 confirmation checksum after transfer completion, but it was missing.'
    end
  end

  def s3_object_upload_opts(multipart_threshold, tags = nil)
    opts = {
      # NOTE: Supplying a checksum_algorithm option with value 'CRC32C' will make the AWS SDK
      # automatically calculate a local CRC32C checksums before sending the file to S3 (for both
      # multipart and single part uploads).  The upload will fail if the corresponding checksum
      # calculated by S3 does not match.
      checksum_algorithm: 'CRC32C',
      progress_callback: PROGRESS_DISPLAY_PROC,
      multipart_threshold: multipart_threshold,
      thread_count: 10 # The number of parallel multipart uploads
    }

    opts[:tagging] = self.class.tags_to_query_string(tags) if tags.present?
    opts
  end
end
