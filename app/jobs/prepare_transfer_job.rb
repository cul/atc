# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
# rubocop:disable Style/MethodCallWithoutArgsParentheses

class PrepareTransferJob < ApplicationJob
  queue_as Atc::Queues::PREPARE_TRANSFER

  def perform(source_object_id, enqueue_successor: true)
    source_object = SourceObject.find(source_object_id)

    whole_file_crc32c_checksum = nil

    pending_transfers = []

    if queue_for_aws?(source_object)
      # AWS uses whole file checksum for smaller files, and multipart checksum for larger files
      if File.size(source_object.path) < Atc::Constants::DEFAULT_MULTIPART_THRESHOLD
        whole_file_crc32c_checksum ||= Digest::CRC32c.file(source_object.path).digest
        pending_transfers << PendingTransfer.create!(
          transfer_checksum_algorithm: crc32c_checksum_algorithm,
          transfer_checksum_value: whole_file_crc32c_checksum,
          storage_provider: aws_storage_provider(),
          source_object: source_object
        )
      else
        checksum_data = Atc::Utils::AwsChecksumUtils.multipart_checksum_for_file(source_object.path)
        pending_transfers << PendingTransfer.create!(
          transfer_checksum_algorithm: crc32c_checksum_algorithm(),
          transfer_checksum_value: checksum_data[:binary_checksum_of_checksums],
          transfer_checksum_part_size: checksum_data[:part_size],
          transfer_checksum_part_count: checksum_data[:num_parts],
          storage_provider: aws_storage_provider(),
          source_object: source_object
        )
      end
    end

    if queue_for_gcp?(source_object)
      # GCP always uses whole file checksum
      whole_file_crc32c_checksum ||= Digest::CRC32c.file(source_object.path).digest
      pending_transfers << PendingTransfer.create!(
        transfer_checksum_algorithm: crc32c_checksum_algorithm(),
        transfer_checksum_value: whole_file_crc32c_checksum,
        storage_provider: gcp_storage_provider(),
        source_object: source_object
      )
    end

    return unless enqueue_successor

    enqueue_successor_jobs(pending_transfers)
  end

  def aws_storage_provider
    @aws_storage_provider ||= StorageProvider.find_by!(
      storage_type: StorageProvider.storage_types[:aws], container_name: AWS_CONFIG[:preservation_bucket_name]
    )
  end

  def gcp_storage_provider
    @gcp_storage_provider ||= StorageProvider.find_by!(
      storage_type: StorageProvider.storage_types[:gcp], container_name: GCP_CONFIG[:preservation_bucket_name]
    )
  end

  def crc32c_checksum_algorithm
    @crc32c_checksum_algorithm ||= ChecksumAlgorithm.find_by!(name: 'CRC32C')
  end

  def queue_for_provider?(storage_provider:, source_object:)
    !PendingTransfer.find_by(storage_provider: storage_provider, source_object: source_object) &&
      !StoredObject.find_by(storage_provider: storage_provider, source_object: source_object)
  end

  def queue_for_aws?(source_object)
    queue_for_provider?(storage_provider: aws_storage_provider(), source_object: source_object)
  end

  def queue_for_gcp?(source_object)
    queue_for_provider?(storage_provider: gcp_storage_provider(), source_object: source_object)
  end

  def enqueue_successor_jobs(pending_transfers)
    pending_transfers.each { |pending_transfer| PerformTransferJob.perform_later(pending_transfer.id) }
    true
  end
end

# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
# rubocop:enable Style/MethodCallWithoutArgsParentheses
