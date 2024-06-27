# frozen_string_literal: true

class PrepareTransferJob < ApplicationJob
  queue_as Atc::Queues::PREPARE_TRANSFER

  def aws_pending_transfers(aws_storage_providers,
                            source_object,
                            whole_file_crc32c_checksum)
    aws_pending_transfers = []
    aws_storage_providers.each do |aws_storage_provider|
      aws_pending_transfers << PendingTransfer.create!(
        transfer_checksum_algorithm: crc32c_checksum_algorithm,
        transfer_checksum_value: whole_file_crc32c_checksum,
        storage_provider: aws_storage_provider,
        source_object: source_object
      )
    end
    aws_pending_transfers
  end

  def aws_pending_transfers_multipart(aws_storage_providers,
                                      source_object,
                                      checksum_data)
    aws_pending_transfers = []
    aws_storage_providers.each do |aws_storage_provider|
      aws_pending_transfers << PendingTransfer.create!(
        transfer_checksum_algorithm: crc32c_checksum_algorithm,
        transfer_checksum_value: checksum_data[:binary_checksum_of_checksums],
        transfer_checksum_part_size: checksum_data[:part_size],
        transfer_checksum_part_count: checksum_data[:num_parts],
        storage_provider: aws_storage_provider,
        source_object: source_object
      )
    end
    aws_pending_transfers
  end

  def gcp_pending_transfers(gcp_storage_providers,
                            source_object,
                            whole_file_crc32c_checksum)
    gcp_pending_transfers = []
    gcp_storage_providers.each do |gcp_storage_provider|
      gcp_pending_transfers << PendingTransfer.create!(
        transfer_checksum_algorithm: crc32c_checksum_algorithm,
        transfer_checksum_value: whole_file_crc32c_checksum,
        storage_provider: gcp_storage_provider,
        source_object: source_object
      )
    end
    gcp_pending_transfers
  end

  def checksum_data(source_object, calculate_whole_object)
    @checksum_data ||= Atc::Utils::AwsChecksumUtils.multipart_checksum_for_file(
      source_object.path,
      calculate_whole_object: calculate_whole_object
    )
  end

  def whole_file_crc32c_checksum(source_object)
    @whole_file_crc32c_checksum ||= Digest::CRC32c.file(source_object.path).digest
  end

  def prep_aws_transfers(aws_storage_providers,
                         source_object,
                         calculate_whole_object)
    # AWS uses whole file checksum for smaller files, and multipart checksum for larger files
    if File.size(source_object.path) < Atc::Constants::DEFAULT_MULTIPART_THRESHOLD
      aws_pending_transfers(aws_storage_providers, source_object, whole_file_crc32c_checksum(source_object))
    else
      aws_pending_transfers_multipart(aws_storage_providers,
                                      source_object,
                                      checksum_data(source_object, calculate_whole_object))
    end
  end

  def prep_gcp_transfers(gcp_storage_providers,
                         source_object)
    gcp_pending_transfers(gcp_storage_providers, source_object, whole_file_crc32c_checksum(source_object))
  end

  def perform(source_object_id, enqueue_successor: true)
    source_object = SourceObject.find(source_object_id)
    pending_transfers = []

    aws_storage_providers = select_storage_providers(source_object, 'aws')
    gcp_storage_providers = select_storage_providers(source_object, 'gcp')

    if aws_storage_providers.present?
      pending_transfers.concat prep_aws_transfers(aws_storage_providers, source_object,
                                                  gcp_storage_providers.present?)
    end

    # GCP always uses whole file checksum
    pending_transfers.concat prep_gcp_transfers(gcp_storage_providers, source_object) if gcp_storage_providers.present?

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
