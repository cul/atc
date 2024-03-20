# frozen_string_literal: true

require 'rails_helper'

describe Atc::Loaders::ChecksumLoader do
  let(:source_object) { FactoryBot.create(:source_object) }
  let(:checksum_alg) { FactoryBot.create(:checksum_algorithm, :sha256) }
  let(:sha256_hex) { '41cd378725458b47f8a45113a81cd30031533cc3f17fba7ce36f8d4d2123e056' }
  let(:checksum_value) { Atc::Utils::HexUtils.hex_to_bin(sha256_hex) }
  let(:enqueue_successor) { false }

  describe '.load' do
    let(:log_io) { instance_double(IO, print: nil) }

    context 'and object has no existing data' do
      let(:dry_run) { false }

      before do
        if enqueue_successor
          expect(PrepareTransferJob).to receive(:perform_later)
        else
          expect(PrepareTransferJob).not_to receive(:perform_later)
        end

        described_class.load(
          checksum_algorithm: checksum_alg,
          source_object_path: source_object.path,
          checksum_value: checksum_value,
          dry_run: dry_run,
          log_io: log_io,
          enqueue_successor: enqueue_successor
        )
        source_object.reload
      end

      it 'assigns the checksums' do
        expect(source_object.fixity_checksum_value).to eql(checksum_value)
        expect(source_object.fixity_checksum_algorithm).to eql(checksum_alg)
      end

      context 'dry_run is true' do
        let(:dry_run) { true }

        it 'does not update the object' do
          expect(source_object.fixity_checksum_value).to be_nil
          expect(source_object.fixity_checksum_algorithm).to be_nil
        end
      end

      context 'proposed value is bad' do
        let(:checksum_value) { sha256_hex }

        it 'does not update the object' do
          expect(source_object.fixity_checksum_value).to be_nil
          expect(source_object.fixity_checksum_algorithm).to be_nil
        end
      end

      context 'enqueue_successor is true' do
        let(:enqueue_successor) { true }

        it 'assigns the checksums' do
          expect(source_object.fixity_checksum_value).to eql(checksum_value)
          expect(source_object.fixity_checksum_algorithm).to eql(checksum_alg)
        end
      end
    end
  end

  describe '.checksum_already_assigned?' do
    before do
      source_object.update(fixity_checksum_value: checksum_value, fixity_checksum_algorithm: checksum_alg)
    end

    context 'and object has the data' do
      it 'returns true' do
        expect(described_class.checksum_already_assigned?(source_object, checksum_alg, checksum_value)).to be true
      end
    end

    context 'and object does not have the data' do
      let(:md5_args) { { name: 'MD5', empty_binary_value: Digest::MD5.new.digest } }
      let(:md5_alg) { FactoryBot.create(:checksum_algorithm, **md5_args) }
      let(:md5_value) { Atc::Utils::HexUtils.hex_to_bin('cd338b723362b4354fdc2acfd2cf0a49') }

      it 'returns false' do
        expect(described_class.checksum_already_assigned?(source_object, md5_alg, md5_value)).to be false
      end
    end
  end
end
