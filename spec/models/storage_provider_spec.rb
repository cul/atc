# frozen_string_literal: true

require 'rails_helper'

describe StorageProvider do
  let(:object_key) { 'some/key.txt' }

  describe 'with valid fields' do
    subject(:storage_provider) { FactoryBot.build(:storage_provider, :aws) }

    it 'saves without error' do
      result = storage_provider.save
      expect(storage_provider.errors.full_messages).to be_blank
      expect(result).to eq(true)
    end
  end

  describe '#local_path_key_map_for_storage_type' do
    let(:local_path_key_map) do
      { '/some/path' => '' }
    end

    it 'works for an aws provider' do
      stub_const('AWS_CONFIG', AWS_CONFIG.merge({ local_path_key_map: local_path_key_map }))
      storage_provider = FactoryBot.build(:storage_provider, :aws)
      expect(storage_provider.local_path_key_map_for_storage_type).to eq(local_path_key_map)
    end

    it 'works for a gcp provider' do
      stub_const('GCP_CONFIG', GCP_CONFIG.merge({ local_path_key_map: local_path_key_map }))
      storage_provider = FactoryBot.build(:storage_provider, :gcp)
      expect(storage_provider.local_path_key_map_for_storage_type).to eq(local_path_key_map)
    end

    it 'raises an exception for an unsupported provider' do
      storage_provider = FactoryBot.build(:storage_provider, :cul)
      expect { storage_provider.local_path_key_map_for_storage_type }.to raise_error(NotImplementedError)
    end
  end

  describe '#local_path_to_stored_path' do
    subject(:storage_provider) { FactoryBot.build(:storage_provider, :aws) }

    let(:local_path) { '/digital/preservation/path/to/file.txt' }

    it 'converts the given path when it starts with a value in the local_path_key_map' do
      expect(storage_provider.local_path_to_stored_path(local_path)).to eq('path/to/file.txt')
    end

    it 'raises an error when the given path does not start with a value in the local_path_key_map' do
      expect {
        storage_provider.local_path_to_stored_path('/unexpected/path/to/file.txt')
      }.to raise_error(Atc::Exceptions::StorageProviderMappingNotFound)
    end
  end

  context 'AWS provider type' do
    subject(:storage_provider) { FactoryBot.build(:storage_provider, :aws) }

    let(:pending_transfer) { FactoryBot.build(:pending_transfer, :aws) }
    let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
    let(:bucket_name) { 'example_bucket' }
    let(:aws_s3_uploader) do
      Atc::Aws::S3Uploader.new(s3_client, bucket_name)
    end

    describe '#storage_implemented?' do
      it 'returns true' do
        expect(storage_provider.storage_implemented?).to be true
      end
    end

    describe '#perform_transfer' do
      before do
        allow(storage_provider).to receive(:aws_s3_uploader).and_return(aws_s3_uploader)
      end

      let(:expected_metadata) { { 'a' => 'b' } }
      let(:expected_tags) { { 'c' => 'd' } }

      it 'performs as expected' do
        expect(aws_s3_uploader).to receive(:upload_file).with(
          pending_transfer.source_object.path,
          object_key,
          :whole_file,
          overwrite: false, metadata: expected_metadata,
          tags: expected_tags, precalculated_aws_crc32c: 'm6nHZg=='
        )
        storage_provider.perform_transfer(
          pending_transfer, object_key,
          metadata: expected_metadata, tags: expected_tags
        )
      end
    end
  end

  context 'GCP provider type' do
    subject(:storage_provider) { FactoryBot.build(:storage_provider, :gcp) }

    let(:pending_transfer) { FactoryBot.build(:pending_transfer, :gcp) }
    let(:bucket_name) { 'example_bucket' }
    let(:gcp_storage_client) do
      Google::Cloud::Storage.new(credentials: GcpMockCredentials.new(GCP_CONFIG[:credentials]))
    end
    let(:gcp_storage_uploader) do
      Atc::Gcp::StorageUploader.new(gcp_storage_client, bucket_name)
    end

    describe '#storage_implemented?' do
      it 'returns true' do
        expect(storage_provider.storage_implemented?).to be true
      end
    end

    describe '#perform_transfer' do
      before do
        allow(storage_provider).to receive(:gcp_storage_uploader).and_return(gcp_storage_uploader)
      end

      let(:expected_metadata) { { 'a' => 'b' } }

      it 'performs as expected' do
        expect(gcp_storage_uploader).to receive(:upload_file).with(
          pending_transfer.source_object.path,
          object_key,
          overwrite: false,
          metadata: expected_metadata,
          precalculated_whole_file_crc32c: 'm6nHZg=='
        )
        storage_provider.perform_transfer(
          pending_transfer, object_key,
          metadata: expected_metadata
        )
      end

      it 'raises an ArgumentError when tags are provided (because GCP does not support tags)' do
        expect {
          storage_provider.perform_transfer(
            pending_transfer, object_key,
            metadata: expected_metadata,
            tags: { 'some-tag-key' => 'some-tag-value' }
          )
        }.to raise_error(
          ArgumentError,
          "#{storage_provider.storage_type} storage provider does not support tags. Use metadata instead."
        )
      end
    end
  end

  context 'CUL provider type' do
    describe '#perform_transfer' do
      let(:storage_provider) { FactoryBot.build(:storage_provider, :cul) }
      let(:pending_transfer) { FactoryBot.build(:pending_transfer, storage_provider: storage_provider) }

      it 'raises an exception because the method has not been fully implemented a the cul storage provider' do
        expect {
          storage_provider.perform_transfer(pending_transfer, 'some-key', metadata: nil)
        }.to raise_error(NotImplementedError)
      end
    end
  end

  describe 'validations' do
    let(:new_storage_provider) { described_class.new }

    it 'must have a storage_type' do
      expect(new_storage_provider.valid?).to be(false)
      expect(new_storage_provider.errors).to include(:storage_type)
    end

    it 'must have a container_name' do
      expect(new_storage_provider.valid?).to be(false)
      expect(new_storage_provider.errors).to include(:container_name)
    end

    it "raises exception on save if storage_type and container_name pair aren't unique" do
      sp1 = described_class.create!(
        storage_type: described_class.storage_types[:aws], container_name: 'some-container-name'
      )
      sp2 = described_class.new(
        storage_type: sp1.storage_type, container_name: sp1.container_name
      )
      expect { sp2.save }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
