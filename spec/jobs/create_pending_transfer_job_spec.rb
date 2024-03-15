# frozen_string_literal: true

require 'rails_helper'

describe CreatePendingTransferJob do
  let(:create_pending_transfer_job) { described_class.new }
  let(:source_object) { FactoryBot.create(:source_object) }
  let(:source_object_with_tempfile) { FactoryBot.create(:source_object, :with_tempfile) }
  let(:invalid_source_object_id) { 987_654 }
  let(:expected_checksum) { [12, 60, 211, 11].pack('C*') }
  let(:aws_id) { StorageProvider.find_by!(storage_type: StorageProvider.storage_types[:aws]).id }
  let(:gcp_id) { StorageProvider.find_by!(storage_type: StorageProvider.storage_types[:gcp]).id }
  let(:multipart_threshold) { 100.megabytes }

  it 'creates the expected PendingTransfer record for a file below the multipart threshold' do
    create_pending_transfer_job.perform(source_object.id)
    aws = PendingTransfer.find_by(source_object_id: source_object.id, storage_provider_id: aws_id)
    gcp = PendingTransfer.find_by(source_object_id: source_object.id, storage_provider_id: gcp_id)

    expect(aws).not_to be_nil
    expect(gcp).not_to be_nil
    expect(aws.transfer_checksum_value).to eq(expected_checksum)
  end

  it 'creates the expected PendingTransfer record for a file above the multipart threshold' do
    Tempfile.create(source_object_with_tempfile.path, binmode: true) do |f|
      f.write('A' * (multipart_threshold + 1.megabytes))
      f.flush
      allow(File).to receive(:open).with(source_object_with_tempfile.path, 'rb').and_return(f)
      allow(File).to receive(:size).with(source_object_with_tempfile.path).and_return(multipart_threshold + 1.megabytes)

      create_pending_transfer_job.perform(source_object_with_tempfile.id)
      aws = PendingTransfer.find_by(source_object_id: source_object_with_tempfile.id, storage_provider_id: aws_id)
      gcp = PendingTransfer.find_by(source_object_id: source_object_with_tempfile.id, storage_provider_id: gcp_id)

      expect(aws).not_to be_nil
      expect(gcp).not_to be_nil
      expect(aws.transfer_checksum_value).to eq(expected_checksum)
    end
  end

  it 'fails to create a PendingTransfer if the given source object id cannot be resolved to a SourceObject record' do
    # Raises ActiveRecord::RecordNotFound if no SourceObject has that id.
    expect { create_pending_transfer_job.perform(invalid_source_object_id) }.to raise_error ActiveRecord::RecordNotFound
  end
end
