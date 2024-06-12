# frozen_string_literal: true

class Atc::Aws::FixityCheck
  def initialize(stored_object, stream_id)
    @bucket_name = stored_object.storage_provider.container_name
    @object_path = stored_object.path
    @fixity_checksum_algorithm = stored_object.source_object.fixity_checksum_algorithm
    @stream_id = stream_id
  end

  def fixity_checksum_object_size
    aws_fixity_check_response =
      parse_json_response_aws_fixity_websocket_channel_stream
    case aws_fixity_check_response['type']
    when 'fixity_check_complete'
      [aws_fixity_check_response['data']['checksum_hexdigest'], aws_fixity_check_response['data']['object_size'], nil]
    when 'fixity_check_error'
      # if only want to return the error from the AWS fixity response, without data,
      # use the following commented-out line instead of the last line
      # [nil, nil, aws_fixity_check_response['data']['error_message']]
      [nil, nil, response_data_as_string(aws_fixity_check_response)]
    end
  end

  def response_data_as_string(aws_fixity_check_response)
    # AWS response data contains, among other things, the error message
    "AWS error response with the following data: #{aws_fixity_check_response['data']} "
  end

  # method will be adapted/changed once helper class method is available
  def parse_json_response_aws_fixity_websocket_channel_stream
    JSON.parse(aws_fixity_websocket_channel_stream(@bucket_name,
                                                   @object_path,
                                                   @fixity_checksum_algorithm,
                                                   @stream_id))
  end

  # following is a placeholder. Will be replaced by call to helper class method,
  # or client code will be added to this method instead
  # Method will  possibly be merged with #parse_json_response_aws_fixity_websocket_channel_stream
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
