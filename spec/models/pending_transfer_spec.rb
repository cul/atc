# frozen_string_literal: true

require 'rails_helper'

describe PendingTransfer do
  subject(:pending_transfer) { FactoryBot.build(:pending_transfer) }

  describe 'with valid fields' do
    it 'saves without error' do
      result = pending_transfer.save
      expect(pending_transfer.errors.full_messages).to be_blank
      expect(result).to eq(true)
    end
  end

  describe 'validations' do
    it 'fails to save when a positive size object has a zero-byte checksum value' do
      pending_transfer.transfer_checksum_value = pending_transfer.transfer_checksum_algorithm.empty_binary_value
      expect(pending_transfer.save).to eq(false)
      expect(pending_transfer.errors).to include(:transfer_checksum_value)
    end

    it 'fails to save its source object is missing a fixity_checksum_value' do
      pending_transfer.source_object.fixity_checksum_value = nil
      expect(pending_transfer.save).to eq(false)
      expect(pending_transfer.errors).to include(:source_object)
    end

    it 'fails to save its source object is missing a fixity_checksum_algorithm' do
      pending_transfer.source_object.fixity_checksum_algorithm = nil
      expect(pending_transfer.save).to eq(false)
      expect(pending_transfer.errors).to include(:source_object)
    end
  end

  context 'with a no-content checksum' do
    let(:pending_transfer_with_zero_byte_size_and_empty_binary_value_checksum) do
      obj = FactoryBot.build(
        :pending_transfer,
        source_object: FactoryBot.create(:source_object, :with_zero_byte_object_size, :with_checksum)
      )
      obj.transfer_checksum_value = obj.transfer_checksum_algorithm.empty_binary_value
      obj
    end
    let(:pending_transfer_with_positive_byte_size_and_empty_binary_value_checksum) do
      obj = FactoryBot.build(:pending_transfer)
      obj.transfer_checksum_value = obj.transfer_checksum_algorithm.empty_binary_value
      obj
    end

    it 'saves without error if the object size is zero' do
      result = pending_transfer_with_zero_byte_size_and_empty_binary_value_checksum.save
      expect(pending_transfer_with_zero_byte_size_and_empty_binary_value_checksum.errors).to be_blank
      expect(result).to be(true)
    end

    it 'fails to save when object size is a positive number' do
      expect(pending_transfer_with_positive_byte_size_and_empty_binary_value_checksum.save).to eq(false)
      expect(
        pending_transfer_with_positive_byte_size_and_empty_binary_value_checksum.errors
      ).to include(:transfer_checksum_value)
    end
  end

  describe 'checksum values' do
    let(:content) { 'This is the content' }
    let(:crc32c_checksum_algorithm) { FactoryBot.create(:checksum_algorithm, :crc32c) }
    let(:crc32c_content_checksum) { Digest::CRC32c.digest(content) }

    it 'can store a crc32c checksum value in transfer_checksum_value' do
      pending_transfer = FactoryBot.build(
        :pending_transfer,
        transfer_checksum_algorithm: crc32c_checksum_algorithm,
        transfer_checksum_value: crc32c_content_checksum
      )
      expect(pending_transfer.save).to eq(true)
      pending_transfer.reload
      expect(pending_transfer.transfer_checksum_value.length).to eq(4)
    end
  end
end
