# frozen_string_literal: true

MULTI_PART_REQUIRED_SIZE = 100.megabytes

class CreatePendingTransferJob < ApplicationJob
  queue_as Atc::Queues::CREATE_PENDING_TRANSFER

  def perform(source_object_id)
    source_object, file_size, whole_file_checksum = calculate_whole_file_checksum source_object_id

    if file_size > MULTI_PART_REQUIRED_SIZE
      part_size = Aws::S3::MultipartFileUploader.new.send(:compute_default_part_size, file_size)

      multi_part_checksum = calculate_multi_part_checksum(source_object.file_path, part_size)
      PendingTransfer.create(transfer_checksum_algorithm_id: :aws, transfer_checksum_value: multi_part_checksum,
                             transfer_chunk_size: part_size)
    else
      PendingTransfer.create(transfer_checksum_algorithm_id: :aws, transfer_checksum_value: whole_file_checksum,
                             transfer_chunk_size: nil)
    end
    PendingTransfer.create(transfer_checksum_algorithm_id: :gcp, transfer_checksum_value: whole_file_checksum,
                           transfer_chunk_size: nil)
  end

  def calculate_whole_file_checksum(source_object_id)
    # Raises ActiveRecord::RecordNotFound if no SourceObject has that id.
    source_object = SourceObject.find(source_object_id)
    file_path = source_object.file_path
    file_size = File.size(file_path)

    whole_file_checksum = nil
    File.open(file_path, 'rb') { |file| whole_file_checksum = Digest::CRC32c.digest(file.read) }
    [source_object, file_size, whole_file_checksum]
  end

  def calculate_multi_part_checksum(file_path, part_size)
    c2c32c_bin_checksums_for_parts = []
    File.open(file_path, 'rb') do |file|
      while (buffer = file.read(part_size))
        c2c32c_bin_checksums_for_parts << Digest::CRC32c.digest(buffer)
      end
    end
    multi_part_checksum = Digest::CRC32c.new
    c2c32c_bin_checksums_for_parts.each { |checksum| multi_part_checksum.update(checksum) }
    multi_part_checksum
  end
end
