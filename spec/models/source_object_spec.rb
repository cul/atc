# frozen_string_literal: true

require 'rails_helper'

describe SourceObject do
  let(:sha256_checksum_algorithm) { FactoryBot.create(:checksum_algorithm, :sha256) }

  describe 'validations' do
    subject(:source_object) { FactoryBot.create(:source_object) }

    it 'has a path_hash of 32 bytes' do
      expect(source_object.path_hash.bytesize).to be 32
    end

    it 'does not permit reassignment of path' do
      expect { source_object.update!(path: 'LQSyM') }.to raise_error ActiveRecord::RecordInvalid
    end
  end

  context 'with a no-content checksum' do
    let(:source_object_with_zero_byte_size_and_empty_binary_value_checksum) do
      FactoryBot.build(
        :source_object,
        object_size: 0,
        fixity_checksum_algorithm: sha256_checksum_algorithm,
        fixity_checksum_value: sha256_checksum_algorithm.empty_binary_value
      )
    end
    let(:source_object_with_positive_byte_size_and_empty_binary_value_checksum) do
      FactoryBot.build(
        :source_object,
        object_size: 1,
        fixity_checksum_algorithm: sha256_checksum_algorithm,
        fixity_checksum_value: sha256_checksum_algorithm.empty_binary_value
      )
    end

    it 'saves without error the object size is zero' do
      expect(source_object_with_zero_byte_size_and_empty_binary_value_checksum.save).to eq(true)
    end

    it 'fails to save when object size is a positive number' do
      expect(source_object_with_positive_byte_size_and_empty_binary_value_checksum.save).to eq(false)
      expect(
        source_object_with_positive_byte_size_and_empty_binary_value_checksum.errors
      ).to include(:fixity_checksum_value)
    end
  end

  describe 'checksum values' do
    let(:content) { 'This is the content' }
    let(:sha512_checksum_algorithm) { FactoryBot.create(:checksum_algorithm, :sha512) }
    let(:sha256_content_checksum) { Digest::SHA256.digest(content) }
    let(:sha512_content_checksum) { Digest::SHA512.digest(content) }

    it 'can store a sha256 checksum value in fixity_checksum_value' do
      source_object = FactoryBot.build(
        :source_object,
        object_size: content.length,
        fixity_checksum_algorithm: sha256_checksum_algorithm,
        fixity_checksum_value: sha256_content_checksum
      )
      expect(source_object.save).to eq(true)
      source_object.reload
      expect(source_object.fixity_checksum_value.length).to eq(32)
    end

    it 'can store a sha512 checksum value in fixity_checksum_value' do
      source_object = FactoryBot.build(
        :source_object,
        object_size: content.length,
        fixity_checksum_algorithm: sha512_checksum_algorithm,
        fixity_checksum_value: sha512_content_checksum
      )
      expect(source_object.save).to eq(true)
      source_object.reload
      expect(source_object.fixity_checksum_value.length).to eq(64)
    end
  end
end
