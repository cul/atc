# frozen_string_literal: true

# rubocop:disable RSpec/MultipleExpectations
# rubocop:disable RSpec/ExampleLength

require 'rails_helper'

describe PrepareTransferJob do
  let(:prepare_transfer_job) { described_class.new }
  let(:source_object) { FactoryBot.create(:source_object, :with_checksum) }
  # Capture the first piece of the path, including trailing slash
  let(:path_prefix) { source_object.path.match(%r{/[^/]+/})[0] }
  let(:source_object_without_checksum) { FactoryBot.create(:source_object) }
  let!(:aws_storage_provider) { FactoryBot.create(:storage_provider, :aws) }
  let!(:gcp_storage_provider) { FactoryBot.create(:storage_provider, :gcp) }
  let(:crc32c_checksum_algorithm) { FactoryBot.create(:checksum_algorithm, :crc32c) }
  let(:tempfile_base_path) do
    base_path = nil
    Tempfile.create('throwaway-file') do |f|
      base_path = f.path.match(%r{/[^/]+/})[0] # Capture the first piece of the path, including trailing slash
    end
    base_path
  end

  before do
    stub_const('ATC', ATC.merge({
      source_paths_to_storage_providers: {
        # Add a mapping for our source_object's path
        path_prefix.to_sym => {
          path_mapping: '',
          storage_providers: [
            {
              storage_type: aws_storage_provider.storage_type,
              container_name: aws_storage_provider.container_name
            },
            {
              storage_type: gcp_storage_provider.storage_type,
              container_name: gcp_storage_provider.container_name
            }
          ]
        },
        # Add a mapping for the tempfile base path (for some of the tests in this file)
        tempfile_base_path.to_sym => {
          path_mapping: '',
          storage_providers: [
            {
              storage_type: aws_storage_provider.storage_type,
              container_name: aws_storage_provider.container_name
            },
            {
              storage_type: gcp_storage_provider.storage_type,
              container_name: gcp_storage_provider.container_name
            }
          ]
        }
      }
    }))
  end

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

  context 'skipping unnecessary PendingTransfer creation' do
    context 'PendingTransfers already exist' do
      it 'skips creation of an AWS-bound PendingTransfer if one already exists, '\
         'and only creates a GCP-bound PendingTransfer' do
        FactoryBot.create(
          :pending_transfer, storage_provider: FactoryBot.create(:storage_provider, :aws), source_object: source_object
        )
        expect(PendingTransfer).to receive(:create!).once.with(
          transfer_checksum_algorithm: crc32c_checksum_algorithm,
          transfer_checksum_value: String,
          storage_provider: gcp_storage_provider,
          source_object: source_object
        )
        prepare_transfer_job.perform(source_object.id, enqueue_successor: false)
      end

      it 'skips creation of an GCP-bound PendingTransfer if one already exists, '\
         'and only creates an AWS-bound PendingTransfer' do
        FactoryBot.create(
          :pending_transfer, storage_provider: FactoryBot.create(:storage_provider, :gcp), source_object: source_object
        )
        expect(PendingTransfer).to receive(:create!).once.with(
          transfer_checksum_algorithm: crc32c_checksum_algorithm,
          transfer_checksum_value: String,
          storage_provider: aws_storage_provider,
          source_object: source_object
        )
        prepare_transfer_job.perform(source_object.id, enqueue_successor: false)
      end

      it 'does not create any PendingTransfers if corresponding AWS and GCP PendingTransfers already exist' do
        FactoryBot.create(
          :pending_transfer, storage_provider: FactoryBot.create(:storage_provider, :aws), source_object: source_object
        )
        FactoryBot.create(
          :pending_transfer, storage_provider: FactoryBot.create(:storage_provider, :gcp), source_object: source_object
        )
        expect(PendingTransfer).not_to receive(:create!)
        prepare_transfer_job.perform(source_object.id, enqueue_successor: false)
      end
    end

    context 'corresponding StoredObjects already exist' do
      it 'skips creation of an AWS-bound PendingTransfer if a corresponding StoredObject already exists, '\
         'and only creates a GCP-bound PendingTransfer' do
        FactoryBot.create(
          :stored_object, storage_provider: FactoryBot.create(:storage_provider, :aws), source_object: source_object
        )
        expect(PendingTransfer).to receive(:create!).once.with(
          transfer_checksum_algorithm: crc32c_checksum_algorithm,
          transfer_checksum_value: String,
          storage_provider: gcp_storage_provider,
          source_object: source_object
        )
        prepare_transfer_job.perform(source_object.id, enqueue_successor: false)
      end

      it 'skips creation of a GCP-bound PendingTransfer if a corresponding StoredObject already exists, '\
         'and only creates an AWS-bound PendingTransfer' do
        FactoryBot.create(
          :stored_object,
          storage_provider: FactoryBot.create(:storage_provider, :gcp), source_object: source_object
        )
        expect(PendingTransfer).to receive(:create!).once.with(
          transfer_checksum_algorithm: crc32c_checksum_algorithm,
          transfer_checksum_value: String,
          storage_provider: aws_storage_provider,
          source_object: source_object
        )
        prepare_transfer_job.perform(source_object.id, enqueue_successor: false)
      end

      it 'does not create any PendingTransfers if corresponding AWS and GCP StoredObjects already exist' do
        FactoryBot.create(
          :stored_object, storage_provider: FactoryBot.create(:storage_provider, :aws), source_object: source_object
        )
        FactoryBot.create(
          :stored_object, storage_provider: FactoryBot.create(:storage_provider, :gcp), source_object: source_object
        )
        expect(PendingTransfer).not_to receive(:create!)
        prepare_transfer_job.perform(source_object.id, enqueue_successor: false)
      end
    end
  end
end
