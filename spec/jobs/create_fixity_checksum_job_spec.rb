# frozen_string_literal: true

require 'rails_helper'

describe CreateFixityChecksumJob do
  subject(:create_fixity_checksum_job) { described_class.new }

  let(:source_object) { FactoryBot.create(:source_object, path: 'spec/fixtures/files/content.txt') }
  let(:checksum_alg) { FactoryBot.create(:checksum_algorithm, :sha256) }
  let(:sha256_hex) { '3fb728d59eee29ba4623ba1a71acd5dda4b236a0a1e685f91078941fdfc6464f' }

  describe '#perform' do
    let(:expected_checksum) { Atc::Utils::HexUtils.hex_to_bin(sha256_hex) }

    it 'updates object with fixity checksum if none exists' do
      create_fixity_checksum_job.perform(source_object.id, enqueue_successor: false)
      source_object.reload
      expect(source_object.fixity_checksum_value).to eql(expected_checksum)
      expect(source_object.fixity_checksum_algorithm).to eql(checksum_alg)
    end

    context 'when fixity checksum exists' do
      let(:md5_args) { { name: 'MD5', empty_binary_value: Digest::MD5.new.digest } }
      let(:prior_checksum_alg) { FactoryBot.create(:checksum_algorithm, **md5_args) }
      let(:prior_checksum_value) { Atc::Utils::HexUtils.hex_to_bin(Digest::MD5.file(source_object.path).hexdigest) }

      before do
        source_object.update(fixity_checksum_algorithm: prior_checksum_alg, fixity_checksum_value: prior_checksum_value)
      end

      it 'return false without updating when override is false' do
        create_fixity_checksum_job.perform(source_object.id, enqueue_successor: false)
        source_object.reload
        expect(source_object.fixity_checksum_value).to eql(prior_checksum_value)
        expect(source_object.fixity_checksum_algorithm).to eql(prior_checksum_alg)
      end

      it 'updates object when override is true' do
        create_fixity_checksum_job.perform(source_object.id, override: true, enqueue_successor: false)
        source_object.reload
        expect(source_object.fixity_checksum_value).to eql(expected_checksum)
        expect(source_object.fixity_checksum_algorithm).to eql(checksum_alg)
      end
    end

    context 'when enqueuing successor' do
      it 'calls PrepareTransferJob.perform_later' do
        expect(PrepareTransferJob).to receive(:perform_later).with(source_object.id, enqueue_successor: true)
        create_fixity_checksum_job.perform(source_object.id, enqueue_successor: true)
        source_object.reload
        expect(source_object.fixity_checksum_value).to eql(expected_checksum)
        expect(source_object.fixity_checksum_algorithm).to eql(checksum_alg)
      end
    end
  end

  describe '#calculate_fixity_checksum' do
    let(:expected_checksum) { Atc::Utils::HexUtils.hex_to_bin(sha256_hex) }

    it 'returns digest byte string' do
      expect(create_fixity_checksum_job.calculate_fixity_checksum(source_object, checksum_alg))
        .to eql(expected_checksum)
    end

    context 'unknown checksum algorithm' do
      let(:checksum_alg) { instance_double(ChecksumAlgorithm, name: 'SHA718') }

      it 'returns nil for unknown checkum implementation' do
        expect(create_fixity_checksum_job.calculate_fixity_checksum(source_object, checksum_alg)).to be_nil
      end
    end
  end
end
