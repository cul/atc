# frozen_string_literal: true

class Atc::Aws::FixityCheck
  def initialize(stored_object, fixity_check_identifier)
    @bucket_name = stored_object.storage_provider.container_name
    @object_path = stored_object.path
    @fixity_checksum_algorithm = stored_object.source_object.fixity_checksum_algorithm
    @fixity_check_identifier = fixity_check_identifier
  end

  # Returns an array with the checksum, object size, and (if something went wrong) an error error_message.
  # If there is an error, checksum and object size will be nil.  If there is not an error,
  # checksum and object size will be non-nil and error will be nil.
  # @return [Array(String, Integer, String)] A 3-element array containing: [checksum, object_size, error_message]
  def fixity_checksum_object_size
    response = Atc::Aws::RemoteFixityCheck.new(
      CHECK_PLEASE['http_base_url'], CHECK_PLEASE['ws_url'], CHECK_PLEASE['auth_token']
    ).perform(
      @fixity_check_identifier, @bucket_name,
      @object_path, @fixity_checksum_algorithm.name.downcase,
      Atc::Aws::RemoteFixityCheck::HTTP
    )
    [response['checksum_hexdigest'], response['object_size'], response['error_message']]
  end
end
