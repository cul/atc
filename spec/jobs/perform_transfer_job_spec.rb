# frozen_string_literal: true

require 'rails_helper'

describe PerformTransferJob do
  let(:perform_transfer_job) { described_class.new }
  let(:aws_storage_provider) { FactoryBot.create(:storage_provider, :aws) }
  let(:pending_transfer) { FactoryBot.create(:pending_transfer, storage_provider: aws_storage_provider) }
  let(:object_key) { 'safe/object/key.jpg' }
  let(:expected_tags) { { 'checksum-sha256' => '31a961575a28515eb6645610a736b0465ef24f9105892e18808294afe70c00f6' } }

  before do
    allow(PendingTransfer).to receive(:find).with(pending_transfer.id).and_return(pending_transfer)
    allow(aws_storage_provider).to receive(:local_path_to_stored_path).with(
      pending_transfer.source_object.path
    ).and_return(object_key)
  end

  it 'creates the expected StoredObject record' do
    expect(aws_storage_provider).to receive(:perform_transfer).with(pending_transfer, object_key, expected_tags)
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
    expect(aws_storage_provider).not_to receive(:perform_transfer).with(pending_transfer, object_key, expected_tags)
    perform_transfer_job.perform(pending_transfer.id)
    expect(StoredObject.count).to eq(1) # only one StoredObject should exist, not two
  end

  context 'when an Atc::Exceptions::ObjectExists error is encountered' do
    before do
      # The first time that perform_transfer is called, we'll have it raise an exception
      # to pretend we encountered a key that's in use.
      allow(aws_storage_provider).to receive(:perform_transfer).with(
        pending_transfer, object_key, expected_tags
      ).and_raise(Atc::Exceptions::ObjectExists)
      # The second time that perform_transfer is called, we expect it to receive a renamed variation
      # and an 'original-path' tag, and we'll raise an exception again to pretend there's another collision.
      allow(aws_storage_provider).to receive(:perform_transfer).with(
        pending_transfer, object_key.sub('.jpg', '_1.jpg'), expected_tags.merge({ 'original-path' => object_key })
      ).and_raise(Atc::Exceptions::ObjectExists)
    end

    it 'appends a numbered variation to the key, and adds an original-path tag' do
      # The third time that perform_transfer is called, we expect it to receive a different
      # renamed variation and an 'original-path' tag, and we won't raise an exception.
      expect(aws_storage_provider).to receive(:perform_transfer).with(
        pending_transfer, object_key.sub('.jpg', '_2.jpg'), expected_tags.merge({ 'original-path' => object_key })
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
        pending_transfer, expected_remediated_key, expected_tags.merge({ 'original-path' => object_key })
      )
      perform_transfer_job.perform(pending_transfer.id)
      expect(StoredObject.first.path).to eq(expected_remediated_key)
    end
  end
end
