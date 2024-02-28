# frozen_string_literal: true

require 'rails_helper'

describe TransferSource do
  let(:well_known_input) { 'MySQL' }
  let(:well_known_digest) { '211906c1c32db77e3082ad28ae2eb3130f83d6e7a6150b6aa6ab6545173c13a7' }

  describe 'validations' do
    subject(:transfer_source) { described_class.create!(path: well_known_input, object_size: object_size) }

    let(:object_size) { 2048 } # any vaue fine for these tests

    it 'has a path_hash of 32 bytes' do
      expect(transfer_source.path_hash.bytesize).to be 32
    end

    it 'does not permit reassignment of path' do
      expect { transfer_source.update!(path: 'LQSyM') }.to raise_error ActiveRecord::RecordInvalid
    end
  end
end
