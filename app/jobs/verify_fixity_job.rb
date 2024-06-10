# frozen_string_literal: true

class VerifyFixityJob < ApplicationJob
  queue_as Atc::Queues::VERIFY_FIXITY

  # spec present
  def perform(stored_object_id)
    stored_object = StoredObject.find(stored_object_id)

    existing_fixity_verification_record = FixityVerification.find_by(stored_object: stored_object)
    return if existing_fixity_verification_record&.pending?

    if existing_fixity_verification_record
      process_existing_fixity_verification_record existing_fixity_verification_record
    end
    fixity_verification_record = create_pending_fixity_verification stored_object
    verify_fixity fixity_verification_record
  end

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

  def verify_fixity(fixity_verification_record)
    if fixity_verification_record.stored_object.storage_provider.aws?
      @check_fixity = Atc::Aws::FixityCheck.new(fixity_verification_record.stored_object,
                                                fixity_verification_record.id)
    # add an 'elsif' clause once GCP is also fixity-checked.
    else
      # throw exception as well?
      Rails.logger.warn 'Unsupported storage provider'
    end
    _object_checksum, _object_size, _fixity_check_error = @check_fixity.fixity_checksum_object_size
  end

  def object_checksum_and_size_match?(stored_object, provider_object_checksum, provider_object_size)
    # Needs additional implementation!!!
    if checksums_match?(stored_object, provider_object_checksum) &&
       (stored_object.source_object.object_size == provider_object_size)
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
