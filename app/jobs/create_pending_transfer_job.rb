# frozen_string_literal: true

multi_part_required_size = 100.megabytes

class CreatePendingTransferJob < ApplicationJob
  queue_as Atc::Queues::CREATE_PENDING_TRANSFER

  def perform(transfer_source_id)
    # Raises ActiveRecord::RecordNotFound if no TransferSource has that id.
    transfer_source = TransferSource.find(transfer_source_id)
    file_size = File.size(transfer_source.file_path)

    whole_file_checksum = nil
    File.open(file_path, 'rb') do |file|
      whole_file_checksum = Digest::CRC32c.digest(file.read)
    end

    if file_size > multi_part_required_size
      part_size = Aws::S3::MultipartFileUploader.new.send(:compute_default_part_size, file_size)

      multi_part_checksum = calculate_multi_part_checksum part_size

      PendingTransfer.create(
        transfer_checksum_algorithm_id: :aws,
        transfer_checksum_value: multi_part_checksum,
        transfer_chunk_size: part_size
      )
    else
      PendingTransfer.create(
        transfer_checksum_algorithm_id: :aws,
        transfer_checksum_value: whole_file_checksum,
        transfer_chunk_size: nil
      )
    end
    PendingTransfer.create(
      transfer_checksum_algorithm_id: :gcp,
      transfer_checksum_value: whole_file_checksum,
      transfer_chunk_size: nil
    )
  end

  def calculate_multi_part_checksum(part_size)
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
