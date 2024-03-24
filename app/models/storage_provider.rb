# frozen_string_literal: true

class StorageProvider < ApplicationRecord
  enum storage_type: { aws: 0, gcp: 1, cul: 2 }

  validates :storage_type, :container_name, presence: true

  def raise_unimplemented_storage_type_error!
    raise NotImplementedError,
          "StorageProvider storage_type #{storage_provider.storage_type} "\
          'is not implemented yet.'
  end

  def storage_implemented?
    case self.storage_type
    when 'aws'
      true
    else
      false
    end
  end

  def perform_transfer(pending_transfer, stored_object_key, tags)
    if self.storage_type == 'aws'
      s3_uploader = Atc::Aws::S3Uploader.new(S3_CLIENT, self.container_name)
      s3_uploader.upload_file(
        pending_transfer.source_object.path,
        stored_object_key,
        pending_transfer.transfer_checksum_part_size.nil? ? :whole_file : :multipart,
        **upload_file_opts(pending_transfer, tags)
      )
      return true
    end

    raise_unimplemented_storage_type_error!
  end

  def local_path_to_stored_path(local_path)
    if self.storage_type == 'aws'
      local_path_key_map = AWS_CONFIG[:local_path_key_map]
      matching_local_path_prefix = local_path_key_map.keys.find do |local_file_prefix|
        local_path.start_with?(local_file_prefix.to_s)
      end

      if matching_local_path_prefix.nil?
        raise "Could not find #{self.storage_type} storage provider "\
              "mapping for #{local_path}"
      end

      return local_path.sub(matching_local_path_prefix.to_s, local_path_key_map[matching_local_path_prefix])
    end

    raise_unimplemented_storage_type_error!
  end

  private

  def upload_file_opts(pending_transfer, tags)
    {
      overwrite: false, # This will raise an Atc::Exceptions::ObjectExists error if the object exists
      tags: tags,
      precalculated_aws_crc32c: [
        Base64.strict_encode64(pending_transfer.transfer_checksum_value),
        pending_transfer.transfer_checksum_part_count
      ].compact.join('-')
    }
  end
end
