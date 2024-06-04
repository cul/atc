# frozen_string_literal: true

class VerifyFixityJob < ApplicationJob
  queue_as Atc::Queues::VERIFY_FIXITY

  def perform(stored_object_id)
    stored_object = StoredObject.find(stored_object_id)

    # Handle possible existing FixityVerification for this StoredObject
    if (existing_fixity_verification = FixityVerification.find_by(stored_object: stored_object))
      process_existing_fixity_verification existing_fixity_verification
    end

    # here, need to see which storage provider contains the stored_object
    if stored_object.storage_provider.aws?
      aws_verify_fixity(stored_object)
    elsif stored_object.storage_provider.gcp?
      gcp_verify_fixity(stored_object)
    else
      Rails.logger.warn 'Unsupported storage provider'
    end
  end

  def fixity_verification_exists(existing_fixity_verification)
    # Need clarification on how to handle each of the follow when statements, in addition to returning
    if existing_fixity_verification.pending?
      Rails.logger.warn 'VerifyFixityJob::perform - FixityVerification exists, pending, no-op'
    elsif existing_fixity_verification.success?
      Rails.logger.warn 'VerifyFixityJob::perform - FixityVerification exists, success, no-op'
    elsif existing_fixity_verification.failure?
      Rails.logger.warn 'VerifyFixityJob::perform - FixityVerification exists, failure, no-op'
    else
      Rails.logger.warn 'VerifyFixityJob::perform - FixityVerification exists, unexpected status, no-op'
    end
  end

  def aws_verify_fixity(stored_object)
    fixity_verification_record = FixityVerification.create!(source_object: stored_object.source_object,
                                                            stored_object: stored_object)
    fixity_verification_record.pending! # saves to the database
    # fixity_checksum = Atc::Utils::HexUtils.bin_to_hex(stored_object.source_object.fixity_checksum_value)

    # Question: is the AWS S3 object key the same as StoredObject.path?
    # For now, assume yes. Howver, may need to add prefix
    aws_fixity_check_response =
      JSON.parse(aws_fixity_websocket_channel_stream(AWS_CONFIG[:preservation_bucket_name],
                                                     stored_object.path,
                                                     stored_object.source_object.fixity_checksum_algorithm,
                                                     fixity_verification_record.id))
    process_aws_fixity_check_response aws_fixity_check_response
  end

  def gcp_verify_fixity(_stored_object)
    Rails.logger.warn 'GCP fixity checks are not implemented'
  end

  def process_aws_fixity_check_response(aws_fixity_check_response)
    case aws_fixity_check_response[:type]
    when 'fixity_check_complete'
      fixity_verification_record.success!
    when 'fixity_check_error'
      aws_fixity_channel_error = aws_fixity_check_response[:type][:data][:error_message]
      fixity_verification.error_message = aws_fixity_channel_error
      fixity_verification_record.failure! # saves to the database
      Rails.logger.warn "AWS fixity channel error for #{stored_object.path}: #{aws_fixity_channel_error}"
    end
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
end
