# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength

class PrepareTransferJob < ApplicationJob
  queue_as Atc::Queues::PREPARE_TRANSFER

  def perform(source_object_id)
    source_object = SourceObject.find(source_object_id)
    whole_file_checksum = Digest::CRC32c.file(source_object.path).digest
    crc32c_checksum_algorithm = ChecksumAlgorithm.find_by!(name: 'CRC32C')

    aws_storage_provider = StorageProvider.find_by!(
      storage_type: StorageProvider.storage_types[:aws], container_name: AWS_CONFIG[:preservation_bucket_name]
    )
    gcp_storage_provider = StorageProvider.find_by!(
      storage_type: StorageProvider.storage_types[:gcp], container_name: GCP_CONFIG[:preservation_bucket_name]
    )

    # AWS uses whole file checksum for smaller files, and multipart checksum for larger files
    if File.size(source_object.path) < Atc::Constants::DEFAULT_MULTIPART_THRESHOLD
      PendingTransfer.create!(
        transfer_checksum_algorithm: crc32c_checksum_algorithm,
        transfer_checksum_value: whole_file_checksum,
        storage_provider: aws_storage_provider,
        source_object: source_object
      )
    else
      checksum_data = Atc::Utils::AwsChecksumUtils.multipart_checksum_for_file(source_object.path)
      PendingTransfer.create!(
        transfer_checksum_algorithm: crc32c_checksum_algorithm,
        transfer_checksum_value: checksum_data[:binary_checksum_of_checksums],
        transfer_checksum_part_size: checksum_data[:part_size],
        transfer_checksum_part_count: checksum_data[:num_parts],
        storage_provider: aws_storage_provider,
        source_object: source_object
      )
    end

    # GCP always uses whole file checksum
    PendingTransfer.create!(
      transfer_checksum_algorithm: crc32c_checksum_algorithm,
      transfer_checksum_value: whole_file_checksum,
      storage_provider: gcp_storage_provider,
      source_object: source_object
    )
  end
end
