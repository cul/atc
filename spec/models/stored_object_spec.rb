# frozen_string_literal: true

require 'rails_helper'

describe StoredObject do
  subject(:stored_object) { FactoryBot.build(:stored_object) }

  describe 'with valid fields' do
    it 'saves without error' do
      result = stored_object.save
      expect(stored_object.errors.full_messages).to be_blank
      expect(result).to eq(true)
    end
  end

  describe 'validations' do
    subject(:stored_object) { FactoryBot.create(:stored_object) }

    it 'has a path_hash of 32 bytes' do
      expect(stored_object.path_hash.bytesize).to be 32
    end

    it 'does not permit reassignment of path' do
      expect { stored_object.update!(path: 'LQSyM') }.to raise_error ActiveRecord::RecordInvalid
    end

    it 'fails to save when a positive size object has a zero-byte checksum value' do
      stored_object.transfer_checksum_value = stored_object.transfer_checksum_algorithm.empty_value
      expect(stored_object.save).to eq(false)
      expect(stored_object.errors).to include(:transfer_checksum_value)
    end
  end

  context 'with a no-content checksum' do
    let(:stored_object_with_zero_byte_size_and_empty_value_checksum) do
      obj = FactoryBot.build(
        :stored_object,
        source_object: FactoryBot.create(:source_object, :with_zero_byte_object_size)
      )
      obj.transfer_checksum_value = obj.transfer_checksum_algorithm.empty_value
      obj
    end
    let(:stored_object_with_positive_byte_size_and_empty_value_checksum) do
      obj = FactoryBot.build(:stored_object)
      obj.transfer_checksum_value = obj.transfer_checksum_algorithm.empty_value
      obj
    end

    it 'saves without error the object size is zero' do
      expect(stored_object_with_zero_byte_size_and_empty_value_checksum.save).to eq(true)
    end

    it 'fails to save when object size is a positive number' do
      expect(stored_object_with_positive_byte_size_and_empty_value_checksum.save).to eq(false)
      expect(stored_object_with_positive_byte_size_and_empty_value_checksum.errors).to include(:transfer_checksum_value)
    end
  end

  describe 'checksum values' do
    let(:content) { 'This is the content' }
    let(:crc32c_checksum_algorithm) { FactoryBot.create(:checksum_algorithm, :crc32c) }
    let(:crc32c_content_checksum) { Digest::CRC32c.digest(content) }

    it 'can store a crc32c checksum value in transfer_checksum_value' do
      stored_object = FactoryBot.build(
        :stored_object,
        transfer_checksum_algorithm: crc32c_checksum_algorithm,
        transfer_checksum_value: crc32c_content_checksum
      )
      expect(stored_object.save).to eq(true)
      stored_object.reload
      expect(stored_object.transfer_checksum_value.length).to eq(4)
    end
  end
end
