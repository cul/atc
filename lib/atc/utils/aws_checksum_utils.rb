# frozen_string_literal: true

module Atc::Utils::AwsChecksumUtils
  def self.checksum_string_for_file(local_file_path, multipart_threshold)
    file_size = File.size(local_file_path)

    if file_size >= multipart_threshold
      checksum_data = multipart_checksum_for_file(local_file_path)
      # The AWS multi-part checksum below is a checksum plus an indication of the number of multipart parts
      return "#{Base64.strict_encode64(checksum_data[:binary_checksum_of_checksums])}-#{checksum_data[:num_parts]}"
    end

    # Fall back to simple base64 crc32c checksum string for single-part uploads
    Digest::CRC32c.file(local_file_path).base64digest
  end

  # NOTE: This method calls Aws::S3::MultipartFileUploader#compute_default_part_size,
  # which is marked as API-private in the aws-sdk-s3 gem.
  # See original method here:
  # https://github.com/aws/aws-sdk-ruby/blob/6def11f359ba4556c2ddd74dfb1dd4ab91c5dd90/gems/aws-sdk-s3/lib/aws-sdk-s3/multipart_file_uploader.rb#L184
  # We have some tests that monitor whether the underlying compute_default_part_size has changed.
  def self.compute_default_part_size(file_size)
    Aws::S3::MultipartFileUploader.new(client: nil).send(:compute_default_part_size, file_size)
  end

  # Calculates a multi-part checksum-of-checksums for the given file and returns
  # a Hash with the following keys:
  # {
  #   binary_checksum_of_checksums: ...binary value...,
  #   part_size: 12345,
  #   num_parts: 4
  # }
  # @return checksum_info [Hash] An info object
  def self.multipart_checksum_for_file(file_path, calculate_whole_object: false)
    part_size = self.compute_default_part_size(File.size(file_path))

    c2c32c_bin_checksums_for_parts = []
    whole_object_digester = Digest::CRC32c.new if calculate_whole_object
    digest_file(file_path, part_size, c2c32c_bin_checksums_for_parts, whole_object_digester)

    checksum_of_checksums = Digest::CRC32c.new
    c2c32c_bin_checksums_for_parts.each { |checksum| checksum_of_checksums.update(checksum) }
    # NOTE: The values below can be used to create an Amazon-formatted multi-part upload checksum:
    # "#{base64_checksum}-#{num_parts}"
    {
      binary_checksum_of_checksums: checksum_of_checksums.digest,
      binary_checksum_of_whole_file: whole_object_digester&.digest,
      part_size: part_size,
      num_parts: c2c32c_bin_checksums_for_parts.length
    }
  end

  # rubocop:disable Performance/UnfreezeString
  def self.digest_file(file_path, part_size, crc32c_accumulator, whole_object_digester)
    File.open(file_path, 'rb') do |file|
      buffer = String.new
      while file.read(part_size, buffer) != nil
        crc32c_accumulator << Digest::CRC32c.digest(buffer)
        whole_object_digester&.update(buffer)
      end
    end
  end
  # rubocop:enable Performance/UnfreezeString
end
