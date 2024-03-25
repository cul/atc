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

      metadata = {
        "checksum-#{pending_transfer.source_object.fixity_checksum_algorithm.name.downcase}" =>
          Atc::Utils::HexUtils.bin_to_hex(pending_transfer.source_object.fixity_checksum_value)
      }

      if previously_attempted_stored_paths.last != unremediated_first_attempt_stored_path
        add_original_path_metadata!(metadata, unremediated_first_attempt_stored_path)
      end

      storage_provider.perform_transfer(pending_transfer, previously_attempted_stored_paths.last, metadata)
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

  private

  # Modifies the given metadata Hash, adding either a 'original-path-b64' or 'original-path-b64-gz' value
  # based on the number of bytes in the given unremediated_first_attempt_stored_path String.  An 'original-path-b64'
  # key will indicate a base64-encoded version of a smaller-value unremediated_first_attempt_stored_path, and an
  # 'original-path-b64-gz' key will indicate a gzipped THEN base64-encoded version of a larger-value
  # unremediated_first_attempt_stored_path.
  # @param metadata [Hash]
  # @param unremediated_first_attempt_stored_path [String]
  def add_original_path_metadata!(metadata, unremediated_first_attempt_stored_path)
    # NOTE: We're checking the unremediated_first_attempt_stored_path.bytes.length instead of
    # unremediated_first_attempt_stored_path.length because multibyte characters in the path string can make a 1024
    # character path take up more than 1024 bytes.  This is important because our cloud storage providers generally
    # limit metadata by string BYTES rather than string LENGTH.
    if unremediated_first_attempt_stored_path.bytes.length < 1024
      metadata['original-path-b64'] = Base64.strict_encode64(unremediated_first_attempt_stored_path)
      return
    end

    # For higher-byte-length strings, we'll gzip the value before base64 encoding it AND store it with a different key
    metadata['original-path-b64-gz'] = Base64.strict_encode64(
      Zlib::Deflate.deflate(unremediated_first_attempt_stored_path)
    )
  end
end
