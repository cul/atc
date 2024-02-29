FactoryBot.define do
  factory :storage_provider do
    storage_type { StorageProvider.storage_types[:aws] }
    container_name { 'example-bucket' }
  end
end
