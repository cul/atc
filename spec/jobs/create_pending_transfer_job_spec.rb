# frozen_string_literal: true

require 'rails_helper'

describe CreatePendingTransferJob do
  let(:create_pending_transfer_job) { described_class.new }
  let(:source_object) { FactoryBot.create(:source_object) }
  let(:invalid_source_object_id) { 987_654 }
  let(:expected_checksum) { [12, 60, 211, 11].pack('C*') }
  let(:aws_id) { StorageProvider.find_by!(storage_type: StorageProvider.storage_types[:aws]).id }
  let(:gcp_id) { StorageProvider.find_by!(storage_type: StorageProvider.storage_types[:gcp]).id }

  it 'creates the expected PendingTransfer record for a smaller file' do
    create_pending_transfer_job.perform(source_object.id)
    aws = PendingTransfer.find_by(source_object_id: source_object.id, storage_provider_id: aws_id)
    gcp = PendingTransfer.find_by(source_object_id: source_object.id, storage_provider_id: gcp_id)

    puts aws

    expect(aws).not_to be_nil
    expect(gcp).not_to be_nil
    expect(aws.transfer_checksum_value).to eq(expected_checksum)
  end

  it 'fails to create a PendingTransfer if the given source object id cannot be resolved to a SourceObject record' do
    # Raises ActiveRecord::RecordNotFound if no SourceObject has that id.
    expect { create_pending_transfer_job.perform(invalid_source_object_id) }.to raise_error ActiveRecord::RecordNotFound
  end
end
