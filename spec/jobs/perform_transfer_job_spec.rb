# frozen_string_literal: true

require 'rails_helper'

describe PerformTransferJob do
  let(:perform_transfer_job) { described_class.new }
  let(:aws_storage_provider) { FactoryBot.create(:storage_provider, :aws) }
  let(:pending_transfer) { FactoryBot.create(:pending_transfer, storage_provider: aws_storage_provider) }
  # this is the hexed checksum of the pending transfer fixture
  let(:well_known_checksum) { '31a961575a28515eb6645610a736b0465ef24f9105892e18808294afe70c00f6' }
  let(:object_key) { 'safe/object/key.jpg' }
  let(:object_key_as_base64) { Base64.strict_encode64(object_key) }
  let(:metadata_key) { PerformTransferJob::ORIGINAL_PATH_METADATA_KEY }
  let(:expected_metadata) do
    {
      'checksum-sha256-hex' => well_known_checksum,
      metadata_key => object_key_as_base64
    }
  end

  before do
    allow(PendingTransfer).to receive(:find).with(pending_transfer.id).and_return(pending_transfer)
    allow(aws_storage_provider).to receive(:local_path_to_stored_path).with(
      pending_transfer.source_object.path
    ).and_return(object_key)
  end

  it 'creates the expected StoredObject record' do
    expect(aws_storage_provider).to receive(:perform_transfer).with(
      pending_transfer, object_key, metadata: expected_metadata
    )
    perform_transfer_job.perform(pending_transfer.id)
    expect(StoredObject.first.path).to eq(object_key)
  end

  it 'does not create a StoredObject record when a StoredObject record already exists '\
    'for the same storage provider + source_object pair' do
    FactoryBot.create(
      :stored_object,
      storage_provider: pending_transfer.storage_provider,
      source_object: pending_transfer.source_object
    )
    expect(pending_transfer).to receive(:update).with(status: :failure, error_message: String)
    expect(aws_storage_provider).not_to receive(:perform_transfer)
    perform_transfer_job.perform(pending_transfer.id)
    expect(StoredObject.count).to eq(1) # only one StoredObject should exist, not two
  end

  describe '#original_path_metadata' do
    subject(:actual_metadata_value) { actual_metadata[metadata_key] }

    let(:actual_metadata) { perform_transfer_job.original_path_metadata(object_key) }

    it 'returns a value that can be converted to the original proposed key' do
      expect(Base64.strict_decode64(actual_metadata_value).force_encoding(Encoding::UTF_8)).to eql(object_key)
    end

    context 'when a key is encountered that needs remediation' do
      let(:actual_metadata) { perform_transfer_job.original_path_metadata(object_key) }
      let(:b64_encoded_without_zlib) { object_key_as_base64 }
      let(:object_key) { '🎃a/🍕b/c  🎉.jpg' }

      it 'returns a value that can be converted to the original proposed key' do
        expect(Base64.strict_decode64(actual_metadata_value).force_encoding(Encoding::UTF_8)).to eql(object_key)
      end

      context 'when the original path was given in an unexpected encoding' do
        let(:actual_metadata) do
          perform_transfer_job.original_path_metadata(utf16_object_key)
        end
        let(:utf16_object_key) { object_key.encode(Encoding::UTF_16) }

        it 'returns a value that can be converted to the original proposed key in UTF8' do
          expect(Base64.strict_decode64(actual_metadata_value).force_encoding(Encoding::UTF_8)).to eql(object_key)
        end
      end
    end

    context 'when a key is very long' do
      let(:actual_metadata) { perform_transfer_job.original_path_metadata(object_key) }
      let(:expected_original_path_metadata) do
        Base64.strict_encode64(Zlib::Deflate.deflate(object_key.encode(Encoding::UTF_8)))
      end
      let(:metadata_key) { PerformTransferJob::ORIGINAL_PATH_COMPRESSED_METADATA_KEY }
      let(:object_key) { "#{'🎃a/🍕b/' * path_multiples}c  🎉.jpg" }
      let(:path_multiples) { ((PerformTransferJob::LONG_ORIGINAL_PATH_THRESHOLD - 10) / 10).ceil }

      it 'returns a value that can be converted to the original proposed key' do
        gz = Base64.strict_decode64(actual_metadata_value)
        inflated = Zlib::Inflate.inflate(gz)
        expect(inflated.force_encoding(Encoding::UTF_8)).to eql(object_key)
      end
    end
  end

  context 'when an Atc::Exceptions::ObjectExists error is encountered' do
    before do
      # The first time that perform_transfer is called, we'll have it raise an exception
      # to pretend we encountered a key that's in use.
      allow(aws_storage_provider).to receive(:perform_transfer).with(
        pending_transfer, object_key,
        metadata: expected_metadata
      ).and_raise(Atc::Exceptions::ObjectExists)
      # The second time that perform_transfer is called, we expect it to receive a renamed variation
      # and original-path-* metadata, and we'll raise an exception again to pretend there's
      # another collision.
      allow(aws_storage_provider).to receive(:perform_transfer).with(
        pending_transfer, object_key.sub('.jpg', '_1.jpg'),
        metadata: expected_metadata
      ).and_raise(Atc::Exceptions::ObjectExists)
    end

    it 'appends a numbered variation to the key, and adds original-path-* metadata' do
      # The third time that perform_transfer is called, we expect it to receive a different
      # renamed variation and an 'original-path' tag, and we won't raise an exception.
      expect(aws_storage_provider).to receive(:perform_transfer).with(
        pending_transfer, object_key.sub('.jpg', '_2.jpg'),
        metadata: expected_metadata
      )
      perform_transfer_job.perform(pending_transfer.id)
      expect(StoredObject.first.path).to eq(object_key.sub('.jpg', '_2.jpg'))
    end
  end

  context 'when a key is encountered that needs remediation' do
    let(:object_key) { '🎃a/🍕b/c  🎉.jpg' }
    let(:expected_remediated_key) { '_a/_b/c___.jpg' }

    it 'is remediated automatically and the job completes without error' do
      expect(aws_storage_provider).to receive(:perform_transfer).with(
        pending_transfer, expected_remediated_key,
        metadata: expected_metadata
      )
      perform_transfer_job.perform(pending_transfer.id)
      expect(StoredObject.first.path).to eq(expected_remediated_key)
    end
  end

  context 'when a key is very long' do
    let(:path_multiples) { ((PerformTransferJob::LONG_ORIGINAL_PATH_THRESHOLD - 10) / 10).ceil }
    let(:object_key) { "#{'🎃a/🍕b/' * path_multiples}c  🎉.jpg" }
    let(:expected_remediated_key) { "#{'_a/_b/' * path_multiples}c___.jpg" }
    let(:expected_original_path_metadata) do
      {
        'checksum-sha256-hex' => well_known_checksum,
        metadata_key => Base64.strict_encode64(Zlib::Deflate.deflate(object_key))
      }
    end
    let(:metadata_key) { PerformTransferJob::ORIGINAL_PATH_COMPRESSED_METADATA_KEY }

    it 'is remediated automatically and the job completes without error' do
      expect(aws_storage_provider).to receive(:perform_transfer).with(
        pending_transfer, expected_remediated_key,
        metadata: expected_original_path_metadata
      )
      perform_transfer_job.perform(pending_transfer.id)
      expect(StoredObject.first.path).to eq(expected_remediated_key)
    end
  end
end
