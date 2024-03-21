# frozen_string_literal: true

namespace :atc do
  namespace :aws do
    desc 'Upload a file to Amazon S3'
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

      puts "Calculating sha256 checksum for #{local_file_path} ..."
      sha256_hexdigest = Digest::SHA256.file(local_file_path).hexdigest
      puts "sha256 checksum is: #{sha256_hexdigest}"

      # TODO: Decide what we want this key to be.  Right now, it just uploads the file
      # at the top level of the bucket and retains its original name.  It's easy to change
      # though, and we could potentially make it a rake task argument.
      target_object_key = File.basename(local_file_path)

      s3_uploader = Atc::Aws::S3Uploader.new(S3_CLIENT, AWS_CONFIG[:preservation_bucket_name])
      s3_uploader.upload_file(
        local_file_path,
        target_object_key,
        :multipart,
        overwrite: overwrite,
        verbose: true,
        tags: {
          'checksum-sha256': sha256_hexdigest
          # 'original-path': 'add this if applicable for the rake task context'
        }
      )
    end
  end
end
