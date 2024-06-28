# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/PerceivedComplexity:
# rubocop:disable Style/MethodCallWithoutArgsParentheses

class PrepareTransferJob < ApplicationJob
  queue_as Atc::Queues::PREPARE_TRANSFER

  def perform(source_object_id, enqueue_successor: true)
    source_object = SourceObject.find(source_object_id)
    whole_file_crc32c_checksum = nil
    pending_transfers = []

    aws_storage_providers = select_storage_providers(source_object, 'aws')
    gcp_storage_providers = select_storage_providers(source_object, 'gcp')

    if aws_storage_providers.present?
      # AWS uses whole file checksum for smaller files, and multipart checksum for larger files
      if File.size(source_object.path) < Atc::Constants::DEFAULT_MULTIPART_THRESHOLD
        whole_file_crc32c_checksum ||= Digest::CRC32c.file(source_object.path).digest
        aws_storage_providers.each do |aws_storage_provider|
          pending_transfers << PendingTransfer.create!(
            transfer_checksum_algorithm: crc32c_checksum_algorithm(),
            transfer_checksum_value: whole_file_crc32c_checksum,
            storage_provider: aws_storage_provider,
            source_object: source_object
          )
        end
      else
        checksum_data ||= Atc::Utils::AwsChecksumUtils.multipart_checksum_for_file(
          source_object.path,
          calculate_whole_object: gcp_storage_providers.present?
        )
        whole_file_crc32c_checksum = checksum_data[:binary_checksum_of_whole_file]
        aws_storage_providers.each do |aws_storage_provider|
          pending_transfers << PendingTransfer.create!(
            transfer_checksum_algorithm: crc32c_checksum_algorithm(),
            transfer_checksum_value: checksum_data[:binary_checksum_of_checksums],
            transfer_checksum_part_size: checksum_data[:part_size],
            transfer_checksum_part_count: checksum_data[:num_parts],
            storage_provider: aws_storage_provider,
            source_object: source_object
          )
        end
      end
    end

    if gcp_storage_providers.present?
      # GCP always uses whole file checksum
      whole_file_crc32c_checksum ||= Digest::CRC32c.file(source_object.path).digest
      gcp_storage_providers.each do |gcp_storage_provider|
        pending_transfers << PendingTransfer.create!(
          transfer_checksum_algorithm: crc32c_checksum_algorithm(),
          transfer_checksum_value: whole_file_crc32c_checksum,
          storage_provider: gcp_storage_provider,
          source_object: source_object
        )
      end
    end

    return unless enqueue_successor

    enqueue_successor_jobs(pending_transfers)
  end

  def crc32c_checksum_algorithm
    @crc32c_checksum_algorithm ||= ChecksumAlgorithm.find_by!(name: 'CRC32C')
  end

  def select_storage_providers(source_object, storage_provider_storage_type)
    unless StorageProvider.storage_types.key?(storage_provider_storage_type.to_s)
      raise ArgumentError, "Invalid storage provider storage type: #{storage_provider_storage_type}"
    end

    source_object.storage_providers_for_source_path.select do |storage_provider|
      storage_provider.send(:"#{storage_provider_storage_type}?") &&
        # Do not select storage provider if associated with an existing PendingTransfer for this source_object
        !PendingTransfer.find_by(storage_provider: storage_provider, source_object: source_object) &&
        # Do not select storage provider if associated with an existing StoredObject for this source_object
        !StoredObject.find_by(storage_provider: storage_provider, source_object: source_object)
    end
  end

  def enqueue_successor_jobs(pending_transfers)
    pending_transfers.each { |pending_transfer| PerformTransferJob.perform_later(pending_transfer.id) }
    true
  end
end
