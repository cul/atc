# frozen_string_literal: true

FactoryBot.define do
  factory :stored_object do
    source_object { association :source_object, :with_checksum }
    path { '/path/to/file' }
    storage_provider { association :storage_provider, :aws }
    transfer_checksum_algorithm { association :checksum_algorithm, :crc32c }
    transfer_checksum_value { Digest::CRC32c.digest('File content') }

    trait :with_part_size do
      transfer_checksum_value { Digest::CRC32c.digest('A' * 6.megabytes) }
      part_size { 1.megabyte }
    end
  end
end
