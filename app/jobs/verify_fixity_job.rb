# frozen_string_literal: true

class VerifyFixityJob < ApplicationJob
  queue_as Atc::Queues::VERIFY_FIXITY

  def perform(stored_object_id)
    stored_object = StoredObject.find(stored_object_id)

    # Handle possible existing FixityVerification for this StoredObject
    return unless (fixity_verification_record = create_fixity_verification_record(stored_object))

    verify_fixity(stored_object, fixity_verification_record)
  end

  def create_fixity_verification_record(stored_object)
    if (existing_fixity_verification_record = FixityVerification.find_by(stored_object: stored_object))
      process_existing_fixity_verification_record(stored_object, existing_fixity_verification_record)
    else
      create_pending_fixity_verification stored_object
    end
  end

  def process_existing_fixity_verification_record(stored_object, existing_fixity_verification_record)
    if existing_fixity_verification_record.pending?
      # don't create a new one. No-op, job will just return
      nil
    elsif existing_fixity_verification_record.success? || existing_fixity_verification_record.failure?
      # Create VerificationPending in new table, delete this one and create new one
      Rails.logger.warn 'VerifyFixityJob::perform - FixityVerification exists, moving it'
      create_pending_fixity_verification stored_object
    else
      # Need to add exception
      Rails.logger.warn 'VerifyFixityJob::perform - FixityVerification exists, unexpected status, no-op'
      nil
    end
  end

  def create_pending_fixity_verification(stored_object)
    fixity_verification_record = FixityVerification.create!(source_object: stored_object.source_object,
                                                            stored_object: stored_object)
    fixity_verification_record.pending! # saves to the database
    fixity_verification_record
  end

  def verify_fixity(stored_object, fixity_verification_record)
    if stored_object.storage_provider.aws?
      aws_verify_fixity(stored_object, fixity_verification_record)
    elsif stored_object.storage_provider.gcp?
      gcp_verify_fixity(stored_object, fixity_verification_record)
    else
      # throw exception as well?
      Rails.logger.warn 'Unsupported storage provider'
    end
  end

  def aws_verify_fixity(stored_object, fixity_verification_record)
    # Question: is the AWS S3 object key the same as StoredObject.path?
    # For now, assume yes. Howver, may need to add prefix
    aws_fixity_checksum_response =
      parse_json_response_aws_fixity_websocket_channel_stream(stored_object, fixity_verification_record)
    aws_fixity_checksum, aws_fixity_error =
      process_aws_fixity_checksum_response(aws_fixity_checksum_response)
    if aws_fixity_error.present?
      fixity_verification_record.error_message = aws_fixity_error
      fixity_verification_record.failure! # saves to the database
    elsif aws_fixity_checksum.present?
      checksums_match?(stored_object, aws_fixity_checksum)
    end
  end

  def parse_json_response_aws_fixity_websocket_channel_stream(stored_object, fixity_verification_record)
    JSON.parse(aws_fixity_websocket_channel_stream(AWS_CONFIG[:preservation_bucket_name],
                                                   stored_object.path,
                                                   stored_object.source_object.fixity_checksum_algorithm,
                                                   fixity_verification_record.id))
  end

  def aws_fixity_websocket_channel_stream(bucket,
                                          object_key,
                                          fixity_checksum_algorithm,
                                          fixity_verification_record_id)
    # fixity_verification_record_id used as stream identifier
    # websocket client code will go here.
    # Response received (assume JSON) is returned as-is.
    # No processing of the response in this method.
  end

  def process_aws_fixity_checksum_response(aws_fixity_check_response)
    case aws_fixity_check_response['type']
    when 'fixity_check_complete'
      [aws_fixity_check_response['data']['checksum_hexdigest'], nil]
    when 'fixity_check_error'
      aws_fixity_channel_error = aws_fixity_check_response['data']['error_message']
      Rails.logger.warn "AWS fixity channel error: #{aws_fixity_channel_error}"
      [nil, aws_fixity_channel_error]
    end
  end

  def checksums_match?(stored_object, aws_fixity_checksum)
    atc_fixity_checksum = Atc::Utils::HexUtils.bin_to_hex(stored_object.source_object.fixity_checksum_value)
    atc_fixity_checksum == aws_fixity_checksum
  end

  def gcp_verify_fixity(_stored_object, _fixity_verification_record)
    # throw exception as well?
    Rails.logger.warn 'GCP fixity checks are not implemented'
  end
end
