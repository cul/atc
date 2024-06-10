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
      aws_verify_fixity(fixity_verification_record)
    elsif fixity_verification_record.stored_object.storage_provider.gcp?
      gcp_verify_fixity(fixity_verification_record)
    else
      # throw exception as well?
      Rails.logger.warn 'Unsupported storage provider'
    end
  end

  def aws_verify_fixity(fixity_record)
    # Question: is the AWS S3 object key the same as StoredObject.path?
    # For now, assume yes. Howver, may need to add prefix
    object_checksum, object_size, aws_fixity_error =
      process_aws_fixity_websocket_channel_stream_response(fixity_record)
    if aws_fixity_error.present?
      fixity_record.error_message = aws_fixity_error
      fixity_record.failure! # saves to the database
      # process_aws_fixity_error(fixity_verification_record)
    elsif object_checksum_and_size_match?(fixity_record.stored_object, object_checksum, object_size)
      fixity_record.success!
    else
      # fixity_record.error_message =
      # aws_fixity_verification_record_error_message aws_fixity_checksum_response
      fixity_record.failure!
    end
  end

  def gcp_verify_fixity(_fixity_verification_record)
    # throw exception as well?
    Rails.logger.warn 'GCP fixity checks are not implemented'
  end

  def process_aws_fixity_websocket_channel_stream_response(fixity_verification_record)
    aws_fixity_check_response =
      parse_json_response_aws_fixity_websocket_channel_stream(fixity_verification_record)
    case aws_fixity_check_response['type']
    when 'fixity_check_complete'
      [aws_fixity_check_response['data']['checksum_hexdigest'], aws_fixity_check_response['data']['object_size'], nil]
    when 'fixity_check_error'
      [nil, nil, aws_fixity_check_response['data']['error_message']]
    end
  end

  # method will be adapted/changed once helper class method is available
  def parse_json_response_aws_fixity_websocket_channel_stream(fixity_record)
    aws_bucket_name = fixity_record.stored_object.storage_provider.container_name
    JSON.parse(aws_fixity_websocket_channel_stream(aws_bucket_name,
                                                   fixity_record.stored_object.path,
                                                   fixity_record.stored_object.source_object.fixity_checksum_algorithm,
                                                   fixity_record.id))
  end

  # following is a placeholder. Will be replaced by call to helper class method
  # and possibly merged with #process_aws_fixity_websocket_channel_stream
  def aws_fixity_websocket_channel_stream(bucket,
                                          object_key,
                                          fixity_checksum_algorithm,
                                          fixity_verification_record_id)
    # fixity_verification_record_id used as stream identifier
    # websocket client code will go here.
    # Response received (assume JSON) is returned as-is.
    # No processing of the response in this method.
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
