# frozen_string_literal: true

# rubocop:disable Rails/Output

class Atc::Gcp::StorageUploader
  def initialize(storage_client, bucket_name)
    @storage_client = storage_client
    @bucket_name = bucket_name
  end

  # Uploads a file to a Google Cloud Storage
  # @param local_file_path [String] Path to a local file to upload.
  # @param object_key [String] Bucket key to use for the uploaded object.
  # @param options [Hash] A hash of options.
  # @option options [Boolean] :overwrite (boolean)
  #   If an object already exists at the target object_key, { overwrite: true } will overwrite it
  #   and { overwrite: false } will raise an exception.
  #   Default value: false
  # @option options [String] :precalculated_whole_file_crc32c
  #   If this option is provided, it will be send to Google during transfer and Google will verify that
  #   the content received matches this checksum.  If this option is omitted, a local crc32c checksum
  #   will be generated right before the upload occurs, and that checksum will be verified with Google.
  # @option options [Boolean] :verbose
  #   If provided, this will print progress messages to stdout (via puts).
  #   Default value: false
  # @option options [Hash] :metadata
  #   A Hash of key-value metadata pairs (and combined length of all keys and values cannot be
  #   greater than 8192 bytes).
  # @return True if the upload succeeded, or throws Atc::Exceptions::TransferError if the transfer failed.
  def upload_file(local_file_path, object_key, **options)
    perform_overwrite_check!(options[:overwrite], object_key)

    precalculated_whole_file_crc32c = options[:precalculated_whole_file_crc32c] ||
                                      calculate_crc32c(local_file_path, verbose: options[:verbose])

    puts 'Performing upload...' if options[:verbose]

    Retriable.retriable(on: [Google::Cloud::UnavailableError], tries: 3, base_interval: 1) do
      bucket.create_file(
        local_file_path, object_key,
        content_type: BestType.mime_type.for_file_name(local_file_path),
        crc32c: precalculated_whole_file_crc32c, metadata: options[:metadata]
      )
    end

    true
  rescue Google::Cloud::InvalidArgumentError, Google::Apis::ClientError => e
    wrap_and_re_raise_gcp_storage_client_error(e, local_file_path, object_key)
  end

  def bucket
    @bucket ||= @storage_client.bucket(@bucket_name)
  end

  def wrap_and_re_raise_gcp_storage_client_error(err, local_file_path, object_key)
    raise Atc::Exceptions::TransferError,
          "A GCP error occurred while attempting to upload file #{local_file_path} to "\
          "#{object_key}. Error message: #{err.message}"
  end

  def calculate_crc32c(local_file_path, verbose: false)
    puts 'Calculating crc32c because one was not provided...' if verbose
    checksum = Digest::CRC32c.file(local_file_path).base64digest
    puts "Done calculating local crc32c checksum (#{checksum})." if verbose
    checksum
  end

  def object_key_exists?(object_key)
    # NOTE: Bucket#file returns nil if file is not found
    bucket.file(object_key).present?
  end

  def perform_overwrite_check!(allow_overwrite, object_key)
    return if allow_overwrite || !object_key_exists?(object_key)

    raise Atc::Exceptions::ObjectExists,
          "Cancelling upload because existing object was found (at: #{object_key}). "\
          'If you want to replace the existing object, set option { overwrite: true }'
  end
end
