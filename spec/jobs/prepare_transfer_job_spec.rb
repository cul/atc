# frozen_string_literal: true

# rubocop:disable RSpec/MultipleExpectations
# rubocop:disable RSpec/ExampleLength

require 'rails_helper'

describe PrepareTransferJob do
  let(:prepare_transfer_job) { described_class.new }
  let(:source_object) { FactoryBot.create(:source_object, :with_checksum) }
  let(:source_object_without_checksum) { FactoryBot.create(:source_object) }
  let!(:aws_storage_provider) { FactoryBot.create(:storage_provider, :aws) }
  let!(:gcp_storage_provider) { FactoryBot.create(:storage_provider, :gcp) }
  let(:crc32c_checksum_algorithm) { FactoryBot.create(:checksum_algorithm, :crc32c) }

  it 'creates the expected PendingTransfer records' do
    expect(source_object.pending_transfers.length).to eq(0)
    prepare_transfer_job.perform(source_object.id, enqueue_successor: false)
    source_object.reload
    expect(source_object.pending_transfers.length).to eq(2)
    pending_transfers = source_object.pending_transfers.sort_by(&:storage_provider_id)
    expect(pending_transfers.map(&:storage_provider)).to eq([aws_storage_provider, gcp_storage_provider])
    expect(
      pending_transfers.map { |pt| Base64.strict_encode64(pt.transfer_checksum_value) }
    ).to eq(['DDzTCw==', 'DDzTCw=='])
  end

  it 'calculates a whole file checksum for a file below the default multipart threshold' do
    Tempfile.create('example-file-to-checksum') do |f|
      f.write('A' * (Atc::Constants::DEFAULT_MULTIPART_THRESHOLD - 1))
      f.flush
      source_object_with_size_below_multipart_threshold = FactoryBot.create(
        :source_object, :with_checksum, path: f.path
      )
      expect(Atc::Utils::AwsChecksumUtils).not_to receive(:multipart_checksum_for_file)
      prepare_transfer_job.perform(source_object_with_size_below_multipart_threshold.id, enqueue_successor: false)
      pending_transfers = source_object_with_size_below_multipart_threshold.pending_transfers
      expect(
        pending_transfers.map { |pt| Base64.strict_encode64(pt.transfer_checksum_value) }
      ).to eq(['NL23Zw==', 'NL23Zw=='])
      expect(
        pending_transfers.map(&:transfer_checksum_algorithm)
      ).to eq([crc32c_checksum_algorithm, crc32c_checksum_algorithm])
      expect(
        pending_transfers.map(&:transfer_checksum_part_count)
      ).to eq([nil, nil])
      expect(
        pending_transfers.map(&:transfer_checksum_part_size)
      ).to eq([nil, nil])
    end
  end

  it 'calculates a multipart file checksum for a file at the default multipart threshold' do
    Tempfile.create('example-file-to-checksum') do |f|
      f.write('A' * Atc::Constants::DEFAULT_MULTIPART_THRESHOLD)
      f.flush
      source_object_with_multipart_threshold_size = FactoryBot.create(:source_object, :with_checksum, path: f.path)
      expect(Atc::Utils::AwsChecksumUtils).to receive(:multipart_checksum_for_file).and_call_original
      prepare_transfer_job.perform(source_object_with_multipart_threshold_size.id, enqueue_successor: false)
      pending_transfers = source_object_with_multipart_threshold_size.pending_transfers
      expect(
        pending_transfers.map { |pt| Base64.strict_encode64(pt.transfer_checksum_value) }
      ).to eq(['RCWvCw==', 'VFWH0A=='])
      expect(
        pending_transfers.map(&:transfer_checksum_algorithm)
      ).to eq([crc32c_checksum_algorithm, crc32c_checksum_algorithm])
      expect(
        pending_transfers.map(&:transfer_checksum_part_count)
      ).to eq([10, nil])
      expect(
        pending_transfers.map(&:transfer_checksum_part_size)
      ).to eq([5_242_880, nil])
    end
  end

  it 'fails to create a PendingTransfer if the given source object id cannot be resolved to a SourceObject record' do
    expect {
      prepare_transfer_job.perform((SourceObject.maximum(:id) || 0) + 1, enqueue_successor: false)
    }.to raise_error(ActiveRecord::RecordNotFound)
  end

  context 'when enqueuing successor' do
    it 'calls PerformTransferJob.perform_later' do
      expect(PerformTransferJob).to receive(:perform_later).with(instance_of(Integer)).twice
      prepare_transfer_job.perform(source_object.id, enqueue_successor: true)
    end
  end
end
