MULTIPART_THRESHOLD = 100.megabytes # must be >= 5.megabytes due to AWS restriction
AWS_FORCED_MULTIPART_THRESHOLD = 5.gigabytes # AWS requires multipart uploads for any files larger than 5.gigabytes

PROGRESS_DISPLAY_PROC = Proc.new do |bytes, totals|
  # puts bytes.map.with_index { |b, i| "Part #{i+1}: #{b} / #{totals[i]}" }.join(' ') + " - Total: #{100.0 * bytes.sum / totals.sum }%"
  print "\r                                               "
  print "\rProgress: #{ (100.0 * bytes.sum / totals.sum).round(2) }% (uploading as #{totals.length} parts)"
end

UPLOAD_OPTS = {
  progress_callback: PROGRESS_DISPLAY_PROC,
  multipart_threshold: MULTIPART_THRESHOLD,
  thread_count: 10, # The number of parallel multipart uploads
  # This checksum_algorithm parameter makes the S3 Ruby SDK automatically calculate CRC32C checksums
  # locally before sending the file (for both multipart and single part).
  # "When you're using an SDK, you can set the value of the x-amz-sdk-checksum-algorithm parameter
  # to the algorithm that you want Amazon S3 to use when calculating the checksum. Amazon S3
  # automatically calculates the checksum value."
  # - https://docs.aws.amazon.com/AmazonS3/latest/userguide/checking-object-integrity.html
  # We can confirm that this is working because the upload response will include a checksum_crc32c
  # value, and the object in S3 will have a checksum associated with it (using the algorithm
  # specified below.)
  checksum_algorithm: 'CRC32C'
}

def multipart_crc32c_base64digest(file_path)
  file_size = File.size(file_path)
  # We'll use the same part_size as the S3 SDK does, since we're doing an independent verification
  # of the same calculation that it's doing.  Invoking a private method on the
  # MultipartFileUploader isn't the best long-term way to get this size, since it could
  # break in a future version of the library, but it works for now.  We should look into a
  # different way in the future.
  part_size = Aws::S3::MultipartFileUploader.new.send(:compute_default_part_size, file_size)

  c2c32c_bin_checksums_for_parts = []
  File.open(file_path, 'rb') do |file|
    while (buffer = file.read(part_size)) do
      c2c32c_bin_checksums_for_parts << Digest::CRC32c.digest(buffer)
    end
  end
  checksum_of_checksums = Digest::CRC32c.new
  c2c32c_bin_checksums_for_parts.each { |checksum| checksum_of_checksums.update(checksum) }
  "#{checksum_of_checksums.base64digest}-#{c2c32c_bin_checksums_for_parts.length}"
end

namespace :atc do
  namespace :aws do
    desc 'Upload a file to AWS S3 with a locally-calculated CRC32C checksum'
    task upload_file: :environment do
      local_file_path = ENV['local_file_path']
      overwrite = ENV['overwrite'] == 'true'

      if local_file_path.present?
        unless File.exist?(local_file_path)
          puts Rainbow("Could not find file at local_file_path: #{local_file_path}").red
          next
        end
      else
        puts Rainbow('Missing required argument: local_file_path').red
        next
      end

      # TODO: Decide what we want this key to be.  Right now, it just uploads the file
      # at the top level of the bucket and retains its original name.  It's easy to change
      # though, and we could potentially make it a rake task argument.
      target_object_key = File.basename(local_file_path)

      begin
        puts "Attempting upload of #{local_file_path} to #{AWS_CONFIG[:preservation_bucket_name]} ..."
        s3_object = Aws::S3::Object.new(AWS_CONFIG[:preservation_bucket_name], target_object_key, {client: S3_CLIENT})

        if !overwrite && s3_object.exists?
          puts Rainbow("Cancelling upload because existing object was found at: #{s3_object.key}").red
          puts Rainbow("If you want to replace the existing object, run this task again with: overwrite=true").red
          next
        end

        puts "Uploading...\n"

        success = s3_object.upload_file(
          local_file_path,
          UPLOAD_OPTS
        ) do |resp|
          aws_reported_checksum = resp.checksum_crc32c
          if aws_reported_checksum.present?
            is_multipart_upload = (aws_reported_checksum =~ /[^-]-\d+/) != nil
            puts "\nCRC32C checksum reported back from AWS (#{is_multipart_upload ? 'for combined multi-part upload parts' : 'for single PUT operation upload'}): #{aws_reported_checksum}"
            puts "Additional local checksum verification: #{is_multipart_upload ? multipart_crc32c_base64digest(local_file_path) : Digest::CRC32c.file(local_file_path).base64digest}\n"
          else
            raise 'Error: Expected confirmation checksum after transfer completion, but it was missing.'
          end
        end

        if success
          puts Rainbow("\nUpload complete!").green
        else
          puts Rainbow("\nAn unexpected and unknown error occurred during the upload.").red
        end
      rescue Aws::Errors::ServiceError => e
        puts "An error occurred while attempting to upload file #{local_file_path} to #{s3_object.key}. Error message: #{e.message}"
      end
    end
  end
end
