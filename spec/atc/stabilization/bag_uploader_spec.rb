# frozen_string_literal: true

require 'rails_helper'

describe Atc::Stabilization::BagUploader do
  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:bucket_name) { 'example_bucket' }
  let(:object_key) { 'repo_name_collection_name_20260923_120000/data/file.txt' }
  let(:transfer_manager) { instance_double(Aws::S3::TransferManager, upload_file: true) }
  let(:bag_uploader) do
    allow(Aws::S3::TransferManager).to receive(:new).and_return(transfer_manager)
    described_class.new(bucket_name, s3_client)
  end

  def stub_object_count(key_count)
    s3_client.stub_responses(:list_objects_v2, { key_count: key_count })
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(bag_uploader).to be_a(described_class)
    end

    it 'exposes the bucket name' do
      expect(bag_uploader.bucket_name).to eq(bucket_name)
    end
  end

  describe '#upload_file' do
    it 'uploads the local file to the given object key, with a crc32c checksum' do
      bag_uploader.upload_file('/tmp/file.txt', object_key)
      expect(transfer_manager).to have_received(:upload_file).with(
        '/tmp/file.txt', hash_including(bucket: bucket_name, key: object_key, checksum_algorithm: 'CRC32C')
      )
    end

    it 'sets the content type of the file, based on its extension' do
      bag_uploader.upload_file('/tmp/file.tiff', object_key)
      expect(transfer_manager).to have_received(:upload_file).with(
        '/tmp/file.tiff', hash_including(content_type: 'image/tiff')
      )
    end
  end

  describe '#directory_exists' do
    it 'returns true when at least one object shares the prefix' do
      stub_object_count(1)
      expect(bag_uploader.directory_exists('example_directory')).to be(true)
    end

    it 'returns false when no objects share the prefix' do
      stub_object_count(0)
      expect(bag_uploader.directory_exists('example_directory')).to be(false)
    end

    it 'adds a trailing slash, so that a prefix cannot match a partial directory name' do
      stub_object_count(0)
      bag_uploader.directory_exists('example_directory')
      expect(s3_client.api_requests.last[:params]).to include(bucket: bucket_name, prefix: 'example_directory/')
    end

    it 'does not add a second trailing slash when the directory path already ends in one' do
      stub_object_count(0)
      bag_uploader.directory_exists('example_directory/')
      expect(s3_client.api_requests.last[:params]).to include(prefix: 'example_directory/')
    end
  end
end
