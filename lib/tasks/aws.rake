# frozen_string_literal: true

namespace :atc do
  namespace :aws do
    desc 'Run a fixity check using a remote CheckPlease app deployment.'
    task fixity_check: :environment do
      bucket_name = ENV['bucket_name']
      object_path = ENV['object_path']
      checksum_algorithm_name = ENV['checksum_algorithm_name']

      job_identifier = "fixity-check-from-rake-task-#{SecureRandom.uuid}"
      remote_fixity_check = Atc::Aws::RemoteFixityCheck.new(
        CHECK_PLEASE['http_base_url'], CHECK_PLEASE['ws_url'], CHECK_PLEASE['auth_token']
      )
      response = remote_fixity_check.perform(
        job_identifier, bucket_name, object_path, checksum_algorithm_name,
        Atc::Aws::RemoteFixityCheck::WEBSOCKET
      )
      puts "Response: #{response.inspect}"
    end

    desc 'Upload a file to Amazon S3.  This task only exists for transfer testing purposes.'
    task upload_file: :environment do
      if Rails.env != 'development'
        puts 'This task is just for transfer testing and should only be run in a development environment.'
        next
      end

      local_file_path = ENV['local_file_path']
      bucket_name = ENV['bucket_name']
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

      s3_uploader = Atc::Aws::S3Uploader.new(S3_CLIENT, bucket_name)
      s3_uploader.upload_file(
        local_file_path,
        target_object_key,
        :auto,
        overwrite: overwrite,
        verbose: true,
        metadata: {
          'checksum-sha256-hex': sha256_hexdigest,
          'original-path-b64' => Base64.strict_encode64(target_object_key)
        }
      )
    end
  end
end
