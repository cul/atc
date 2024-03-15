# frozen_string_literal: true

require 'rails_helper'

describe StorageProvider do
  describe 'with valid fields' do
    subject(:storage_provider) { FactoryBot.build(:storage_provider, :aws) }

    it 'saves without error' do
      result = storage_provider.save
      expect(storage_provider.errors.full_messages).to be_blank
      expect(result).to eq(true)
    end
  end

  describe 'validations' do
    let(:new_storage_provider) { described_class.new }

    it 'must have a storage_type' do
      expect(new_storage_provider.valid?).to be(false)
      expect(new_storage_provider.errors).to include(:storage_type)
    end

    it 'must have a container_name' do
      expect(new_storage_provider.valid?).to be(false)
      expect(new_storage_provider.errors).to include(:container_name)
    end

    it "raises exception on save if storage_type and container_name pair aren't unique" do
      sp1 = described_class.create!(
        storage_type: described_class.storage_types[:aws], container_name: 'some-container-name'
      )
      sp2 = described_class.new(
        storage_type: sp1.storage_type, container_name: sp1.container_name
      )
      expect { sp2.save }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
