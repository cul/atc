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
      PendingTransfer.find_or_create_by!(
        source_object: source_object,
        storage_provider: storage_provider,
        transfer_checksum_algorithm: crc32c_alg,
        transfer_checksum_value: transfer_checksum_data[:binary_checksum_of_checksums],
        transfer_checksum_part_size: transfer_checksum_data[:part_size],
        transfer_checksum_part_count: transfer_checksum_data[:num_parts]
      )
    end

    desc 'Create pending AWS transfer record for a file'
    task store: :environment do
      local_file_path = ENV['local_file_path']
      overwrite = ENV['overwrite'] == 'true'

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

      storage_provider = StorageProvider.find_by!(
        storage_type: StorageProvider.storage_types[:aws],
        container_name: 'cul-dlstor-digital-preservation'
      )

      path_hash = Digest::SHA256.digest(local_file_path)
      source_object = SourceObject.find_by!(path_hash: path_hash)
      pending_transfer = source_object.pending_transfers.detect { |pt| pt.storage_provider == storage_provider }
      if pending_transfer
        upload_options = {
          overwrite: overwrite,
          verbose: true,
          precalculated_aws_crc32c: pending_transfer.checksum_value,
          tags: {
            "checksum-#{source_object.fixity_checksum_algorithm.name.downcase}" => source_object.fixity_checksum_value
          }
        }
        s3_uploader = Atc::Aws::S3Uploader.new(S3_CLIENT, storage_provider.container_name)
        # TODO: Replace with actual path-to-key remediation
        target_object_key = local_file_path.sub('/digital/preservation/', '')
        if s3_uploader.upload_file(
          local_file_path,
          target_object_key,
          **upload_options
        )
          stored_object = StoredObject.create!(
            path: target_object_key,
            source_object: source_object,
            storage_provider: storage_provider,
            transfer_checksum_algorithm: pending_transfer.transfer_checksum_algorithm,
            transfer_checksum_value: pending_transfer.transfer_checksum_value,
            transfer_checksum_part_size: pending_transfer.transfer_checksum_part_size,
            transfer_checksum_part_count: pending_transfer.transfer_checksum_part_count
          )
          pending_transfer.destroy
          puts Rainbow("StoredObject<#{stored_object.id}> for #{local_file_path}").green
        end
      else
        puts Rainbow('No pending transfer for: local_file_path').red
        next
      end
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
