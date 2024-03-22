# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/AbcSize

# We don't expect too many collisions, so we'll only retry a limited number of times.
# This number can be increased later if needed.
NUM_STORED_PATH_COLLISION_RETRIES = 2

class PerformTransferJob < ApplicationJob
  queue_as Atc::Queues::PERFORM_TRANSFER

  def perform(pending_transfer_id)
    pending_transfer = PendingTransfer.find(pending_transfer_id)
    storage_provider = pending_transfer.storage_provider

    # Make sure that an existing StoredObject does not already exist for this
    # storage_provider + source_object pair.
    if StoredObject.exists?(storage_provider: storage_provider, source_object: pending_transfer.source_object)
      pending_transfer.update(
        status: :failure,
        error_message: 'This PendingTransfer was skipped because there is already a StoredObject '\
                       'with the same storage_provider and source_object. Maybe this '\
                       'PendingTransfer was an accidental duplicate?'
      )
      return
    end

    # TODO: Add support for gcp!
    unless storage_provider.storage_type == 'aws'
      Rails.logger.warn "Skipping PendingTransfer #{pending_transfer.id} because its "\
                        "storage_provider.storage_type value (#{storage_provider.storage_type}) "\
                        'is not yet implemented.'
      return
    end

    # We'll keep track of our attempts to store this object with the storage provider.
    # Our first attempt may not work if the storage provider
    previously_attempted_stored_paths = []

    # This is the stored path we would ideally like to use,
    # if no modifications are necessary for storage provider compatibility.
    unremediated_first_attempt_stored_path = storage_provider.local_path_to_stored_path(
      pending_transfer.source_object.path
    )

    # Indicate that this transfer is in progress
    pending_transfer.update!(status: :in_progress)

    Retriable.retriable(
      on: [ActiveRecord::RecordNotUnique, Atc::Exceptions::ObjectExists],
      tries: 1 + NUM_STORED_PATH_COLLISION_RETRIES,
      base_interval: 0, multiplier: 1, rand_factor: 0
    ) do
      previously_attempted_stored_paths << Atc::Utils::ObjectKeyNameUtils.remediate_key_name(
        unremediated_first_attempt_stored_path, previously_attempted_stored_paths
      )

      # Immediately assign this path to the pending transfer because there's a unique index on path.
      # This will prevent any concurrent transfer process from attempting to claim the same path.
      pending_transfer.update!(stored_object_path: previously_attempted_stored_paths.last)

      tags = {
        "checksum-#{pending_transfer.source_object.fixity_checksum_algorithm.name.downcase}" =>
          Atc::Utils::HexUtils.bin_to_hex(pending_transfer.source_object.fixity_checksum_value)
      }

      if previously_attempted_stored_paths.last != unremediated_first_attempt_stored_path
        tags['original-path'] = unremediated_first_attempt_stored_path
      end

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
    pending_transfer.destroy
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
