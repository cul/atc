# frozen_string_literal: true

require 'rails_helper'

describe StorageProvider do
  let(:storage_provider) {  }

  describe 'validations' do
    let(:new_storage_provider) { StorageProvider.new }
    it 'must have a storage_type' do
      expect(new_storage_provider.valid?).to be(false)
      expect(new_storage_provider.errors).to include(:storage_type)
    end

    it 'must have a container_name' do
      expect(new_storage_provider.valid?).to be(false)
      expect(new_storage_provider.errors).to include(:container_name)
    end

    it "raises exception on save if storage_type and container_name pair aren't unique" do
      sp1 = StorageProvider.create!(storage_type: StorageProvider.storage_types[:aws], container_name: 'some-container-name')
      sp2 = StorageProvider.create!(storage_type: StorageProvider.storage_types[:aws], container_name: 'different-container-name')

      sp3 = StorageProvider.new(storage_type: sp1.storage_type, container_name: sp1.container_name)
      expect { sp3.save }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
