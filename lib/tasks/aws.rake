# frozen_string_literal: true

namespace :atc do
  namespace :aws do
    desc 'Create pending AWS transfer record for a file'
    task pending_transfer: :environment do
      local_file_path = ENV['local_file_path']

      if local_file_path.present?
        unless File.exist?(local_file_path)
          puts Rainbow("Could not find file at local_file_path: #{local_file_path}").red
          next
        end
        unless local_file_path.start_with?('/digital/preservation')
          puts Rainbow("Only transferring /digital/preservation content to AWS: #{local_file_path}").red
          next
        end
      else
        puts Rainbow('Missing required argument: local_file_path').red
        next
      end
      path_hash = Digest::SHA256.digest(local_file_path)
      source_object = SourceObject.find_by!(path_hash: path_hash)
      crc32c_alg = ChecksumAlgorithm.find_by!(name: 'CRC32C')
      storage_provider = StorageProvider.find_by!(
        storage_type: StorageProvider.storage_types[:aws],
        container_name: 'cul-dlstor-digital-preservation'
      )
      transfer_checksum_data = Atc::Utils::AwsMultipartChecksumUtils.multipart_checksum_for_file(local_file_path)
      PendingTransfer.create!(
        source_object: source_object,
        storage_provider: storage_provider,
        transfer_checksum_algorithm: crc32c_alg,
        transfer_checksum_value: transfer_checksum_data[:binary_checksum_of_checksums],
        transfer_checksum_part_size: transfer_checksum_data[:part_size],
        transfer_checksum_part_count: transfer_checksum_data[:num_parts]
      )
    end

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
        overwrite: overwrite,
        verbose: true,
        tags: { 'checksum-sha256': sha256_hexdigest }
      )
    end
  end
end
