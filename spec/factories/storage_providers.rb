# frozen_string_literal: true

FactoryBot.define do
  factory :storage_provider do
    trait :aws do
      initialize_with do
        storage_type = StorageProvider.storage_types[:aws]
        container_name = 'some-aws-bucket-name'
        StorageProvider.find_by(storage_type: storage_type, container_name: container_name) || StorageProvider.create(
          storage_type: storage_type,
          container_name: container_name
        )
      end
    end

    trait :gcp do
      initialize_with do
        storage_type = StorageProvider.storage_types[:gcp]
        container_name = 'some-gcp-bucket-name'
        StorageProvider.find_by(storage_type: storage_type, container_name: container_name) || StorageProvider.create(
          storage_type: storage_type,
          container_name: container_name
        )
      end
    end

    trait :cul do
      initialize_with do
        storage_type = StorageProvider.storage_types[:cul]
        container_name = '/cul/cul5'
        StorageProvider.find_by(storage_type: storage_type, container_name: container_name) || StorageProvider.create(
          storage_type: storage_type,
          container_name: container_name
        )
      end
    end
  end
end
