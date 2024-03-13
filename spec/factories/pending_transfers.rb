# frozen_string_literal: true

FactoryBot.define do
  factory :pending_transfer do
    source_object { association :source_object, :with_checksum }
    storage_provider { association :storage_provider, :aws }
    transfer_checksum_algorithm { association :checksum_algorithm, :crc32c }
    transfer_checksum_value { Digest::CRC32c.digest('File content') }

    trait :with_chunk_size do
      transfer_checksum_value { Digest::CRC32c.digest('A' * 6.megabytes) }
      chunk_size { 1.megabyte }
    end
  end
end
