# frozen_string_literal: true

require 'rails_helper'

describe StorageProvider do
  describe 'with valid fields' do
    subject(:storage_provider) { FactoryBot.build(:storage_provider, :aws) }

    it 'saves without error' do
      result = storage_provider.save
      expect(storage_provider.errors.full_messages).to be_blank
      expect(result).to eq(true)
    end
  end

  context 'AWS provider type' do
    subject(:storage_provider) { FactoryBot.build(:storage_provider, :aws) }

    let(:pending_transfer) { FactoryBot.build(:pending_transfer, :aws) }
    let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
    let(:bucket_name) { 'example_bucket' }
    let(:s3_uploader) do
      Atc::Aws::S3Uploader.new(s3_client, bucket_name)
    end
    let(:s3_object_key) { 'some/key.txt' }

    describe '#storage_implemented?' do
      it 'returns true' do
        expect(storage_provider.storage_implemented?).to be true
      end
    end

    describe '#store_aws' do
      before do
        allow(storage_provider).to receive(:s3_uploader).and_return(s3_uploader)
      end

      let(:expected_metadata) { { 'a' => 'b' } }
      let(:expected_tags) { { 'c' => 'd' } }

      it 'performs as expected' do
        expect(s3_uploader).to receive(:upload_file).with(
          pending_transfer.source_object.path,
          s3_object_key,
          :whole_file,
          overwrite: false,
          metadata: expected_metadata,
          tags: expected_tags,
          precalculated_aws_crc32c: 'm6nHZg=='
        )
        storage_provider.store_aws(pending_transfer, s3_object_key, metadata: expected_metadata, tags: expected_tags)
      end
    end
  end

  context 'GCP provider type' do
    subject(:storage_provider) { FactoryBot.build(:storage_provider, :gcp) }

    describe '#storage_implemented?' do
      it 'returns false' do
        expect(storage_provider.storage_implemented?).to be false
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
