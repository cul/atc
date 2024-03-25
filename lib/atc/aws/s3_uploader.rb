# frozen_string_literal: true

# rubocop: disable Metrics/AbcSize

class Atc::Aws::S3Uploader
  PROGRESS_DISPLAY_PROC = proc do |bytes, totals|
    print "\r                                               "
    print "\rProgress: #{(100.0 * bytes.sum / totals.sum).round(2)}% (uploading as #{totals.length} parts)"
  end

  def initialize(s3_client, bucket_name)
    @s3_client = s3_client
    @bucket_name = bucket_name
  end

  # Uploads a file to S3
  # @param local_file_path [String] Path to a local file to upload.
  # @param object_key [String] Bucket key to use for the uploaded object.
  # @param upload_type [String]
  #   One of the following values:
  #     :whole_file - Performs an AWS PUT operation, uploading the entire file at
  #                   once (file must be < 5GB).
  #     :multipart - Performs a multi-part upload, splitting the file up and sending multiple
  #                  parts at the same time (original file must be > 5MB).
  #     :auto - Automatically selects :whole_file or :multipart based on the file size,
  #             internally using Atc::Constants::DEFAULT_MULTIPART_THRESHOLD.
  #   NOTE: See this link for additional AWS multipart limit info:
  #   https://docs.aws.amazon.com/AmazonS3/latest/userguide/qfacts.html
  # @param options [Hash] A hash of options.
  # @option options [Boolean] :overwrite (boolean)
  #   If an object already exists at the target object_key, { overwrite: true } will overwrite it
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
  #   A Hash of key-value tag pairs (ASCII-only values, max length of 256)
  # @option options [Hash] :metadata
  #   A Hash of key-value metadata pairs (and combined length of all keys and values cannot be
  #   greater than 2048 bytes).  Note that if you put any UTF-8 characters in these values
  #   that AWS will automatically convert the entire value to a base64-encoded string with some
  #   extra characters inserted throughout the string.  This value will not be human-readable
  #   in the AWS console.  If you plan to use UTF-8 characters in a value, it's better to base64
  #   encode the entire value BEFORE sending it to AWS because it will be easier to decode later
  #   because it won't have extra AWS-inserted characters.
  # @return True if the upload succeeded, or throws Atc::Exceptions::TransferError if the transfer failed.
  def upload_file(local_file_path, object_key, upload_type, **options)
    s3_object = generate_s3_object(object_key)
    verbose = options[:verbose]
    file_size = File.size(local_file_path)
    multipart_threshold = multipart_threshold_for_upload_type(upload_type, file_size)

    perform_overwrite_check!(options[:overwrite], s3_object)

    precalculated_aws_crc32c = options[:precalculated_aws_crc32c] ||
                               calculate_aws_crc32c(local_file_path, multipart_threshold, verbose)

    puts 'Performing upload...' if verbose
    s3_object.upload_file(
      local_file_path,
      s3_object_upload_opts(multipart_threshold, tags: options[:tags], metadata: options[:metadata], verbose: verbose)
    ) do |resp|
      verify_aws_response_checksum!(resp.checksum_crc32c, precalculated_aws_crc32c)
    end
    puts "\nUpload complete!" if verbose
    true
  rescue Aws::Errors::ServiceError => e
    wrap_and_re_raise_aws_service_error(e, local_file_path, object_key)
  end

  def self.tags_to_query_string(tags)
    tags.map { |key, value| "#{key}=#{Addressable::URI.encode_component(value)}" }.join('&')
  end

  private

  def multipart_threshold_for_upload_type(upload_type, file_size)
    case upload_type
    when :whole_file
      file_size + 1
    when :multipart
      file_size
    when :auto
      Atc::Constants::DEFAULT_MULTIPART_THRESHOLD
    else
      raise ArgumentError, "Invalid upload_type: #{upload_type}"
    end
  end

  def perform_overwrite_check!(allow_overwrite, s3_object)
    return if allow_overwrite || !s3_object.exists?

    raise Atc::Exceptions::ObjectExists,
          "Cancelling upload because existing object was found (at: #{s3_object.key}). "\
          'If you want to replace the existing object, set option { overwrite: true }'
  end

  def wrap_and_re_raise_aws_service_error(err, local_file_path, object_key)
    raise Atc::Exceptions::TransferError,
          "An AWS service error occurred while attempting to upload file #{local_file_path} to "\
          "#{object_key}. Error message: #{err.message}"
  end

  def calculate_aws_crc32c(local_file_path, multipart_threshold, verbose)
    puts 'Calculating precalculated_aws_crc32c because one was not provided...' if verbose
    checksum = Atc::Utils::AwsChecksumUtils.checksum_string_for_file(local_file_path, multipart_threshold)
    puts "Done calculating local crc32c checksum (#{checksum})." if verbose
    checksum
  end

  def generate_s3_object(object_key)
    Aws::S3::Object.new(@bucket_name, object_key, { client: @s3_client })
  end

  def verify_aws_response_checksum!(aws_reported_checksum, precalculated_aws_crc32c)
    if aws_reported_checksum.present?
      if aws_reported_checksum != precalculated_aws_crc32c
        raise Atc::Exceptions::TransferError,
              'File was uploaded to Amazon, and AWS local SDK checksum and remote S3 checksums matched, '\
              'but they did not match our precalculated checksum. This requires manual investigation. '\
              "AWS checksum: #{aws_reported_checksum}, Our local checksum: #{precalculated_aws_crc32c}"
      end
    else
      raise Atc::Exceptions::TransferError,
            'Expected AWS S3 confirmation checksum after transfer completion, but it was missing.'
    end
  end

  def s3_object_upload_opts(multipart_threshold, tags: nil, metadata: nil, verbose: false)
    opts = {
      # NOTE: Supplying a checksum_algorithm option with value 'CRC32C' will make the AWS SDK
      # automatically calculate a local CRC32C checksums before sending the file to S3 (for both
      # multipart and single part uploads).  The upload will fail if the corresponding checksum
      # calculated by S3 does not match.
      checksum_algorithm: 'CRC32C',
      multipart_threshold: multipart_threshold,
      thread_count: 10 # The number of parallel multipart uploads
    }

    opts[:progress_callback] = PROGRESS_DISPLAY_PROC if verbose
    opts[:tagging] = self.class.tags_to_query_string(tags) if tags.present?
    opts[:metadata] = metadata
    opts
  end
end
