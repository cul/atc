# frozen_string_literal: true

module Atc::Utils::AwsMultipartChecksumUtils
  # NOTE: This method calls Aws::S3::MultipartFileUploader#compute_default_part_size,
  # which is marked as API-private in the aws-sdk-s3 gem.
  # See original method here:
  # https://github.com/aws/aws-sdk-ruby/blob/6def11f359ba4556c2ddd74dfb1dd4ab91c5dd90/gems/aws-sdk-s3/lib/aws-sdk-s3/multipart_file_uploader.rb#L184
  # We have some tests that monitor whether the underlying compute_default_part_size has changed.
  def self.compute_default_part_size(file_size)
    Aws::S3::MultipartFileUploader.new.send(:compute_default_part_size, file_size)
  end

  # Calculates a multi-part checksum-of-checksums for the given file and returns
  # a Hash with the following keys:
  # {
  #   base64_checksum: 'abc123',
  #   part_size: 12345,
  #   num_parts: 4
  # }
  # @return checksum_info [Hash] An info object
  def self.checksum_for_file(file_path)
    part_size = self.compute_default_part_size(File.size(file_path))

    c2c32c_bin_checksums_for_parts = []
    File.open(file_path, 'rb') do |file|
      while (buffer = file.read(part_size))
        c2c32c_bin_checksums_for_parts << Digest::CRC32c.digest(buffer)
      end
    end
    checksum_of_checksums = Digest::CRC32c.new
    c2c32c_bin_checksums_for_parts.each { |checksum| checksum_of_checksums.update(checksum) }
    # NOTE: The values below can be used to create an Amazon-formatted multi-part upload checksum:
    # "#{base64_checksum}-#{num_parts}"
    {
      base64_checksum: checksum_of_checksums.base64digest,
      part_size: part_size,
      num_parts: c2c32c_bin_checksums_for_parts.length
    }
  end
end
