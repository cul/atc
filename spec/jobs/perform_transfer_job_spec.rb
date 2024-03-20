# frozen_string_literal: true

require 'rails_helper'

describe PerformTransferJob do
  let(:perform_transfer_job) { described_class.new }
  let(:aws_storage_provider) { FactoryBot.create(:storage_provider, :aws) }
  let(:pending_transfer) { FactoryBot.create(:pending_transfer, storage_provider: aws_storage_provider) }
  let(:expected_key) { File.join('fake-dir', File.basename(pending_transfer.source_object.path)) }
  let(:expected_tags) { { 'checksum-sha256' => '31a961575a28515eb6645610a736b0465ef24f9105892e18808294afe70c00f6' } }

  before do
    allow(PendingTransfer).to receive(:find).with(pending_transfer.id).and_return(pending_transfer)
    allow(aws_storage_provider).to receive(:local_path_to_stored_path).with(
      pending_transfer.source_object.path
    ).and_return(expected_key)
  end

  it 'creates the expected StoredObject record' do
    expect(aws_storage_provider).to receive(:perform_transfer).with(pending_transfer, expected_key, expected_tags)
    perform_transfer_job.perform(pending_transfer.id)
  end

  it 'does not create a StoredObject record when a StoredObject record already exists '\
    'for the same storage provider + source_object pair' do
    FactoryBot.create(
      :stored_object,
      storage_provider: pending_transfer.storage_provider,
      source_object: pending_transfer.source_object
    )
    expect(pending_transfer).to receive(:update).with(status: :failure, error_message: String)
    expect(aws_storage_provider).not_to receive(:perform_transfer).with(pending_transfer, expected_key, expected_tags)
    perform_transfer_job.perform(pending_transfer.id)
  end
end
