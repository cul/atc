# frozen_string_literal: true

require 'rails_helper'

describe ObjectTransfer do
  let(:well_known_input) { 'MySQL' }
  let(:well_known_digest) { '211906c1c32db77e3082ad28ae2eb3130f83d6e7a6150b6aa6ab6545173c13a7' }

  describe 'validations' do
    subject(:object_transfer) do
      described_class.create!(
        transfer_source: transfer_source,
        path: well_known_input,
        storage_provider: storage_provider
      )
    end

    let(:object_size) { 2048 } # any vaue fine for these tests
    let(:transfer_source) { TransferSource.create!(path: well_known_input, object_size: object_size) }
    let(:storage_provider) { StorageProvider.create(name: 'TEST') }

    it 'has a path_hash of 32 bytes' do
      expect(object_transfer.path_hash.bytesize).to be 32
    end

    it 'does not permit reassignment of path' do
      expect { object_transfer.update!(path: 'LQSyM') }.to raise_error ActiveRecord::RecordInvalid
    end
  end
end
