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
    ['aws', 'gcp'].include?(self.storage_type)
  end

  def store_aws(pending_transfer, stored_object_key, metadata:, tags: {})
    aws_s3_uploader.upload_file(
      pending_transfer.source_object.path,
      stored_object_key,
      pending_transfer.transfer_checksum_part_size.nil? ? :whole_file : :multipart,
      **aws_upload_file_opts(pending_transfer, metadata: metadata, tags: tags)
    )
    true
  end

  def aws_s3_uploader
    @aws_s3_uploader ||= Atc::Aws::S3Uploader.new(S3_CLIENT, self.container_name)
  end

  def gcp_storage_uploader
    @gcp_storage_uploader ||= Atc::Gcp::StorageUploader.new(GCP_STORAGE_CLIENT, self.container_name)
  end

  def store_gcp(pending_transfer, stored_object_key, metadata:)
    gcp_storage_uploader.upload_file(
      pending_transfer.source_object.path,
      stored_object_key,
      **gcp_upload_file_opts(pending_transfer, metadata: metadata)
    )
    true
  end

  def perform_transfer(pending_transfer, stored_object_key, metadata:, tags: {})
    case self.storage_type
    when 'aws'
      store_aws(pending_transfer, stored_object_key, metadata: metadata, tags: tags)
    when 'gcp'
      store_gcp(pending_transfer, stored_object_key, metadata: metadata, tags: tags)
    else
      raise_unimplemented_storage_type_error!
    end
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

  def aws_upload_file_opts(pending_transfer, metadata:, tags:)
    {
      overwrite: false, # This will raise an Atc::Exceptions::ObjectExists error if the object exists
      metadata: metadata,
      tags: tags,
      precalculated_aws_crc32c: [
        Base64.strict_encode64(pending_transfer.transfer_checksum_value),
        pending_transfer.transfer_checksum_part_count
      ].compact.join('-')
    }
  end

  def gcp_upload_file_opts(pending_transfer, metadata:)
    {
      overwrite: false, # This will raise an Atc::Exceptions::ObjectExists error if the object exists
      metadata: metadata,
      precalculated_whole_file_crc32c: Base64.strict_encode64(pending_transfer.transfer_checksum_value)
    }
  end
end
