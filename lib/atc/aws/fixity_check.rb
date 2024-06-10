# frozen_string_literal: true

class Atc::Aws::FixityCheck
  def initialize(stored_object, stream_id)
    @bucket_name = stored_object.storage_provider.container_name
    @object_path = stored_object.path
    @fixity_checksum_algorithm = stored_object.source_object.fixity_checksum_algorithm
    @stream_id = stream_id
  end

  # may want to also return @fixity_record so client code does not
  # need to reload it from the database.
  def fixity_checksum_object_size
    object_checksum, object_size, aws_fixity_check_error =
      process_aws_fixity_websocket_channel_stream_response
    if aws_fixity_check_error.present?
      [nil, nil, aws_fixity_check_error]
    else
      [object_checksum, object_size, nil]
    end
  end

  def process_aws_fixity_websocket_channel_stream_response
    aws_fixity_check_response =
      parse_json_response_aws_fixity_websocket_channel_stream
    case aws_fixity_check_response['type']
    when 'fixity_check_complete'
      [aws_fixity_check_response['data']['checksum_hexdigest'], aws_fixity_check_response['data']['object_size'], nil]
    when 'fixity_check_error'
      [nil, nil, aws_fixity_check_response['data']['error_message']]
    end
  end

  # method will be adapted/changed once helper class method is available
  def parse_json_response_aws_fixity_websocket_channel_stream
    JSON.parse(aws_fixity_websocket_channel_stream(@bucket_name,
                                                   @object_path,
                                                   @fixity_checksum_algorithm,
                                                   @stream_id))
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
end
