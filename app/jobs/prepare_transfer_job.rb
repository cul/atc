# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/PerceivedComplexity
# rubocop:disable Layout/LineLength

class PrepareTransferJob < ApplicationJob
  queue_as Atc::Queues::PREPARE_TRANSFER

  def perform(source_object_id, enqueue_successor: true)
    source_object = SourceObject.find(source_object_id)

    aws_storage_provider = StorageProvider.find_by!(
      storage_type: StorageProvider.storage_types[:aws], container_name: AWS_CONFIG[:preservation_bucket_name]
    )
    gcp_storage_provider = StorageProvider.find_by!(
      storage_type: StorageProvider.storage_types[:gcp], container_name: GCP_CONFIG[:preservation_bucket_name]
    )

    existing_aws_pending_transfer = PendingTransfer.find_by(storage_provider: aws_storage_provider, source_object: source_object)
    existing_gcp_pending_transfer = PendingTransfer.find_by(storage_provider: gcp_storage_provider, source_object: source_object)
    existing_aws_stored_object = StoredObject.find_by(storage_provider: aws_storage_provider, source_object: source_object)
    existing_gcp_stored_object = StoredObject.find_by(storage_provider: gcp_storage_provider, source_object: source_object)

    need_to_generate_pending_transfer_for_aws = existing_aws_pending_transfer.nil? && existing_aws_stored_object.nil?
    need_to_generate_pending_transfer_for_gcp = existing_gcp_pending_transfer.nil? && existing_gcp_stored_object.nil?

    return unless need_to_generate_pending_transfer_for_aws || need_to_generate_pending_transfer_for_gcp

    crc32c_checksum_algorithm = ChecksumAlgorithm.find_by!(name: 'CRC32C')
    whole_file_crc32c_checksum = nil

    pending_transfers = []

    if need_to_generate_pending_transfer_for_aws
      # AWS uses whole file checksum for smaller files, and multipart checksum for larger files
      if File.size(source_object.path) < Atc::Constants::DEFAULT_MULTIPART_THRESHOLD
        pending_transfers << PendingTransfer.create!(
          transfer_checksum_algorithm: crc32c_checksum_algorithm,
          transfer_checksum_value: (whole_file_crc32c_checksum ||= Digest::CRC32c.file(source_object.path).digest),
          storage_provider: aws_storage_provider,
          source_object: source_object
        )
      else
        checksum_data = Atc::Utils::AwsChecksumUtils.multipart_checksum_for_file(source_object.path)
        pending_transfers << PendingTransfer.create!(
          transfer_checksum_algorithm: crc32c_checksum_algorithm,
          transfer_checksum_value: checksum_data[:binary_checksum_of_checksums],
          transfer_checksum_part_size: checksum_data[:part_size],
          transfer_checksum_part_count: checksum_data[:num_parts],
          storage_provider: aws_storage_provider,
          source_object: source_object
        )
      end
    end

    if need_to_generate_pending_transfer_for_gcp
      # GCP always uses whole file checksum
      pending_transfers << PendingTransfer.create!(
        transfer_checksum_algorithm: crc32c_checksum_algorithm,
        transfer_checksum_value: whole_file_crc32c_checksum || Digest::CRC32c.file(source_object.path).digest,
        storage_provider: gcp_storage_provider,
        source_object: source_object
      )
    end

    return unless enqueue_successor

    enqueue_successor_jobs(pending_transfers)
  end

  def enqueue_successor_jobs(pending_transfers)
    pending_transfers.each { |pending_transfer| PerformTransferJob.perform_later(pending_transfer.id) }
    true
  end
end
