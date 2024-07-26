# frozen_string_literal: true

class VerifyFixityJob < ApplicationJob
  queue_as Atc::Queues::VERIFY_FIXITY

  def perform(stored_object_id)
    stored_object = StoredObject.find(stored_object_id)

    # For now, handle only AWS fixity check
    return unless stored_object.storage_provider.aws?

    existing_fixity_verification_record = FixityVerification.find_by(stored_object: stored_object)
    return if existing_fixity_verification_record&.pending?

    if existing_fixity_verification_record
      process_existing_fixity_verification_record existing_fixity_verification_record
    end
    fixity_verification_record = create_pending_fixity_verification stored_object
    provider_fixity_check = instantiate_provider_fixity_check fixity_verification_record
    verify_fixity(fixity_verification_record, provider_fixity_check)
  rescue StandardError => e
    handle_unexpected_error(fixity_verification_record, e) unless fixity_verification_record.nil?
  end

  def handle_unexpected_error(fixity_verification_record, err)
    fixity_verification_record.update!(
      status: :failure,
      error_message: "An unexpected error occurred: #{err.message}"
    )
  end

  def process_existing_fixity_verification_record(existing_fixity_verification_record)
    return if existing_fixity_verification_record.pending?

    # for now, just delete the existing FixityVerification. In later implementation, copy the info
    # into an entry in the new table (PastFixityVerifications).
    existing_fixity_verification_record.destroy
  end

  def create_pending_fixity_verification(stored_object)
    FixityVerification.create!(source_object: stored_object.source_object,
                               stored_object: stored_object,
                               status: :pending)
  end

  def instantiate_provider_fixity_check(fixity_verification_record)
    if fixity_verification_record.stored_object.storage_provider.aws?
      Atc::Aws::FixityCheck.new(fixity_verification_record.stored_object,
                                fixity_verification_record.id)
    # add an 'elsif' clause once GCP is also fixity-checked.
    else
      storage_type = fixity_verification_record.stored_object.storage_provider.storage_type
      msg = "No fixity check functionality for storage type #{storage_type}"
      Rails.logger.warn msg
      raise Atc::Exceptions::ProviderFixityCheckNotFound, msg
    end
  end

  def verify_fixity(fixity_verification_record, provider_fixity_check)
    object_checksum, object_size, fixity_check_error = provider_fixity_check.fixity_checksum_object_size

    if fixity_check_error.present?
      fixity_verification_record.error_message = fixity_check_error
      fixity_verification_record.failure!
    elsif object_checksum_and_size_match?(fixity_verification_record, object_checksum, object_size)
      fixity_verification_record.success!
    else
      fixity_verification_record.error_message = 'Checksum and/or object size mismatch.'
      fixity_verification_record.failure!
    end
  end

  def object_checksum_and_size_match?(fixity_verification_record, provider_object_checksum, provider_object_size)
    atc_object_checksum = fixity_verification_record.source_object.fixity_checksum_value
    if checksums_match?(atc_object_checksum, provider_object_checksum) &&
       (fixity_verification_record.stored_object.source_object.object_size == provider_object_size)
      true
    else
      false
    end
  end

  def checksums_match?(atc_object_checksum_bin, provider_object_checksum_hex)
    atc_object_checksum_hex = Atc::Utils::HexUtils.bin_to_hex atc_object_checksum_bin
    atc_object_checksum_hex == provider_object_checksum_hex
  end
end
