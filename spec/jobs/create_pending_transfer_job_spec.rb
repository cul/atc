# frozen_string_literal: true

require 'rails_helper'

describe CreatePendingTransferJob do
  let(:create_pending_transfer_job) { described_class.new }
  let(:source_object) { FactoryBot.create(:source_object) }

  it 'creates the expected PendingTransfer record' do
    create_pending_transfer_job.perform(source_object.id)
    # TODO: Check to see if it created the expected PendingTransfer record with the expected values
    aws = PendingTransfer.find_by(source_object_id: source_object.id, storage_provider_id: :aws)
    gcp = PendingTransfer.find_by(source_object_id: source_object.id, storage_provider_id: :gcp)

    expect(aws.exists?).to eq(true)
    expect(gcp.exists?).to eq(true)
    expect(aws.transfer_checksum_value).to eq(0)

    # expect(aws.exists?).to eq(true)
    # expect(gcp.exists?).to eq(true)
    # expect(aws.transfer_checksum_algorithm_id).to eq(:crc32c)
    # expect(gcp.transfer_checksum_algorithm_id).to eq(:crc32c)
    # expect(aws.transfer_checksum_value).to eq(0)
    # expect(aws.transfer_checksum_value).to eq(0)
    # expect(aws.transfer_checksum_chunk_size).to eq(nil)
    # expect(gcp.transfer_checksum_chunk_size).to eq(nil)
  end

  it 'fails to create a PendingTransfer if the given source object id cannot be resolved to a SourceObject record' do
    # Raises ActiveRecord::RecordNotFound if no SourceObject has that id.
    expect { create_pending_transfer_job.perform(invalid_source_object_id) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
