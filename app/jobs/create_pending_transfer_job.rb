# frozen_string_literal: true

MULTIPART_THRESHOLD = 100.megabytes

class CreatePendingTransferJob < ApplicationJob
  queue_as Atc::Queues::CREATE_PENDING_TRANSFER

  def perform(source_object_id)
    source_object, file_size, whole_file_checksum = calculate_whole_file_checksum source_object_id

    if file_size.to_i > MULTIPART_THRESHOLD
      ENV['AWS_REGION'] = AWS_CONFIG['aws_region']

      part_size, multi_part_checksum = calculate_multi_part_checksum(source_object.path, file_size)
      create_pending_transfer('CRC32C', multi_part_checksum, part_size, :aws, source_object_id)
    else
      create_pending_transfer('CRC32C', whole_file_checksum, nil, :aws, source_object_id)
    end
    create_pending_transfer('CRC32C', whole_file_checksum, nil, :gcp, source_object_id)
  end

  def create_pending_transfer(transfer_checksum_algorithm, transfer_checksum_value,
                              transfer_checksum_part_size, storage_type, source_object_id)
    PendingTransfer.create(
      transfer_checksum_algorithm_id: ChecksumAlgorithm.find_by!(name: transfer_checksum_algorithm).id,
      transfer_checksum_value: transfer_checksum_value,
      transfer_checksum_part_size: transfer_checksum_part_size,
      storage_provider_id: StorageProvider.find_by!(storage_type: StorageProvider.storage_types[storage_type]).id,
      source_object_id: source_object_id
    )
  end

  def calculate_whole_file_checksum(source_object_id)
    # Raises ActiveRecord::RecordNotFound if no SourceObject has that id.
    source_object = SourceObject.find(source_object_id)
    file_path = source_object.path
    file_size = File.size(file_path)

    whole_file_checksum = nil
    File.open(file_path, 'rb') { |file| whole_file_checksum = Digest::CRC32c.digest(file.read) }
    [source_object, file_size, whole_file_checksum]
  end

  def calculate_multi_part_checksum(file_path, file_size)
    part_size = Aws::S3::MultipartFileUploader.new(region: AWS_CONFIG['aws_region'])
                                              .send(:compute_default_part_size, file_size)

    crc32c_bin_checksums_for_parts = []
    File.open(file_path, 'rb') do |file|
      while (buffer = file.read(part_size))
        crc32c_bin_checksums_for_parts << Digest::CRC32c.digest(buffer)
      end
    end
    multi_part_checksum = Digest::CRC32c.new
    crc32c_bin_checksums_for_parts.each { |checksum| multi_part_checksum.update(checksum) }
    [part_size, multi_part_checksum]
  end
end
