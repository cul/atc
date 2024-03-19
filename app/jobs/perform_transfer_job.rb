# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/AbcSize

NUM_STORED_PATH_COLLISION_RETRIES = 3 # TODO: Actually retry later, once we have remediated path logic

class PerformTransferJob < ApplicationJob
  queue_as Atc::Queues::PERFORM_TRANSFER

  def perform(pending_transfer_id)
    pending_transfer = PendingTransfer.find(pending_transfer_id)
    storage_provider = pending_transfer.storage_provider

    # TODO: Add support for gcp!
    unless storage_provider.storage_type == 'aws'
      raise NotImplementedError,
            "Transfers for StorageProvider storage_type #{storage_provider.storage_type} "\
            'are not yet implemented.'
    end

    # We'll keep track of our attempts to store this object with the storage provider.
    # Our first attempt may not work if the storage provider
    previously_attempted_stored_paths = []

    # Indicate that this transfer is in progress
    pending_transfer.update!(status: :in_progress)

    Retriable.retriable(
      on: [ActiveRecord::RecordNotUnique, Atc::Exceptions::ObjectExists],
      tries: 1 + NUM_STORED_PATH_COLLISION_RETRIES,
      base_interval: 0, multiplier: 1, rand_factor: 0
    ) do
      previously_attempted_stored_paths << storage_provider.local_path_to_stored_path(
        pending_transfer.source_object.path
      )

      # Immediately assign this path to the pending transfer because there's a unique index on path.
      # This will prevent any concurrent transfer process from attempting to claim the same path.
      pending_transfer.update!(stored_object_path: previously_attempted_stored_paths.last)

      tags = {
        "checksum-#{pending_transfer.source_object.fixity_checksum_algorithm.name.downcase}" =>
          Atc::Utils::HexUtils.bin_to_hex(pending_transfer.source_object.fixity_checksum_value)
      }

      tags['original-path'] = previously_attempted_stored_paths.first if previously_attempted_stored_paths.length > 1

      storage_provider.perform_transfer(pending_transfer, previously_attempted_stored_paths.last, tags)
    end

    # If we got here, that means that the upload was successful.  We can convert this
    # PendingTransfer record into a StoredObject record.
    StoredObject.create!(
      path: previously_attempted_stored_paths.last,
      source_object: pending_transfer.source_object,
      storage_provider: pending_transfer.storage_provider,
      transfer_checksum_algorithm: pending_transfer.transfer_checksum_algorithm,
      transfer_checksum_value: pending_transfer.transfer_checksum_value,
      transfer_checksum_part_size: pending_transfer.transfer_checksum_part_size,
      transfer_checksum_part_count: pending_transfer.transfer_checksum_part_count
    )

    # And then delete the PendingTransfer record because it's no longer needed:
    pending_transfer.delete
  rescue StandardError => e
    unless e.is_a?(ActiveRecord::RecordNotFound)
      # If an unexpected error occurs, capture it and mark this job as a failure.
      pending_transfer.update(
        status: :failure,
        error_message: e.message
      )
    end

    # And re-raise so that normal job error handling can continue
    raise e
  end
end
