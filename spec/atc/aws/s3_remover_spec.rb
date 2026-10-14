# frozen_string_literal: true

require 'rails_helper'

describe Atc::Aws::S3Remover do
  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:bucket_name) { 'example_bucket' }
  let(:s3_folder_prefix) { 'example/folder/prefix' }
  let(:s3_remover) { described_class.new(bucket_name, s3_client) }

  describe '#initialize' do
    it 'can be instantiated' do
      expect(s3_remover).to be_a(described_class)
    end
  end

  describe '#delete_directory' do
    def stub_objects(*object_keys)
      s3_client.stub_responses(:list_objects_v2, { contents: object_keys.map { |key| { key: key } } })
    end

    def delete_requests
      s3_client.api_requests.select { |api_request| api_request[:operation_name] == :delete_objects }
    end

    it 'deletes all of the objects that share the given prefix' do
      stub_objects("#{s3_folder_prefix}/a.txt", "#{s3_folder_prefix}/b.txt")
      s3_remover.delete_directory(s3_folder_prefix)
      deleted_keys = delete_requests.first[:params][:delete][:objects].map { |object| object[:key] }
      expect(deleted_keys).to eq(["#{s3_folder_prefix}/a.txt", "#{s3_folder_prefix}/b.txt"])
    end

    it 'does not send a delete request when no objects share the given prefix' do
      stub_objects
      s3_remover.delete_directory(s3_folder_prefix)
      expect(delete_requests).to be_empty
    end

    it 'adds a trailing slash, so that a prefix cannot match a partial directory name' do
      stub_objects
      s3_remover.delete_directory(s3_folder_prefix)
      expect(s3_client.api_requests.first[:params]).to include(
        bucket: bucket_name, prefix: "#{s3_folder_prefix}/"
      )
    end
  end
end
