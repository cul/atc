# frozen_string_literal: true

require 'rails_helper'

describe TransferVerification do
  let(:well_known_input) { 'MySQL' }

  describe 'validations' do
    let(:source_size) { 2048 } # any value fine for these tests
    let(:transfer_source) { TransferSource.create!(path: well_known_input, object_size: source_size) }
    let(:checksum_algorithm) { ChecksumAlgorithm.find_by(name: 'MD5') }
    let(:checksum_value) { 'unverified_value' }
    let(:checksum) do
      Checksum.create!(transfer_source: transfer_source, checksum_algorithm: checksum_algorithm, value: checksum_value)
    end
    let(:storage_provider) { StorageProvider.create!(name: 'TEST') }
    let(:object_transfer) do
      ObjectTransfer.create!(
        transfer_source: transfer_source,
        path: well_known_input,
        storage_provider: storage_provider
      )
    end

    context 'data matches source data' do
      subject(:verification) do
        described_class.create!(
          object_transfer: object_transfer, checksum_value: checksum.value,
          checksum_algorithm: checksum_algorithm, object_size: source_size
        )
      end

      it 'works as expected' do
        expect(verification.checksum_value).to eql(checksum_value)
      end
    end

    context 'data does not match source data', pending: true do
      subject(:verification) do
        described_class.create!(
          object_transfer: object_transfer, checksum_value: object_checksum,
          checksum_algorithm: checksum_algorithm, object_size: object_size
        )
      end

      let(:object_checksum) { checksum.value }
      let(:object_size) { source_size }

      context 'for object size' do
        let(:object_size) { source_size + 1 }

        it 'fails' do
          expect { verification }.to raise_error ActiveRecord::RecordInvalid
        end
      end

      context 'for checksum' do
        let(:object_checksum) { "#{checksum.value}_mismatch" }

        it 'fails' do
          expect { verification }.to raise_error ActiveRecord::RecordInvalid
        end
      end

      context 'checksum does not exist' do
        let(:checksum) { nil }
        let(:object_checksum) { checksum_value }

        it 'fails' do
          expect { verification }.to raise_error ActiveRecord::RecordInvalid
        end
      end
    end
  end
end
