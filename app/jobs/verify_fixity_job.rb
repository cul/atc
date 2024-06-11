# frozen_string_literal: true

class VerifyFixityJob < ApplicationJob
  queue_as Atc::Queues::VERIFY_FIXITY

  # missing spec
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
  end

  # spec present
  def process_existing_fixity_verification_record(existing_fixity_verification_record)
    return if existing_fixity_verification_record.pending?

    # for now, just delete the existing FixityVerification. In later implementation, copy the info
    # into an entry in the new table (PastFixityVerifications).
    existing_fixity_verification_record.destroy
  end

  # spec present
  def create_pending_fixity_verification(stored_object)
    fixity_verification_record = FixityVerification.create!(source_object: stored_object.source_object,
                                                            stored_object: stored_object)
    fixity_verification_record.pending! # saves to the database
    fixity_verification_record
  end

  # spec present
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

  # spec present
  def verify_fixity(fixity_verification_record, provider_fixity_check)
    object_checksum, object_size, fixity_check_error = provider_fixity_check.fixity_checksum_object_size
    if fixity_check_error.present?
      fixity_verification_record.error_message = fixity_check_error
      fixity_verification_record.failure!
    elsif object_checksum_and_size_match?(fixity_verification_record, object_checksum, object_size)
      fixity_verification_record.success!
    else
      fixity_verification_record.failure!
    end
  end

  def object_checksum_and_size_match?(fixity_verification_record, provider_object_checksum, provider_object_size)
    # Needs additional implementation!!!
    if checksums_match?(fixity_verification_record, provider_object_checksum) &&
       (fixity_verification_record.stored_object.source_object.object_size == provider_object_size)
      Rails.logger.warn 'Yippee!'
      true
    else
      Rails.logger.warn 'Darn!'
      false
    end
  end

  def checksums_match?(stored_object, object_fixity_checksum)
    atc_fixity_checksum = Atc::Utils::HexUtils.bin_to_hex(stored_object.source_object.fixity_checksum_value)
    atc_fixity_checksum == object_fixity_checksum
  end

  def aws_fixity_verification_record_error_message(_parsed_json_aws_response)
    'Finish implementation'
  end
end
