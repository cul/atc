# frozen_string_literal: true

FactoryBot.define do
  factory :checksum_algorithm do
    trait :sha256 do
      initialize_with do
        ChecksumAlgorithm.find_by(name: 'SHA256') || ChecksumAlgorithm.create(
          name: 'SHA256',
          empty_binary_value: Digest::SHA256.new.digest
        )
      end
    end

    trait :sha512 do
      initialize_with do
        ChecksumAlgorithm.find_by(name: 'SHA512') || ChecksumAlgorithm.create(
          name: 'SHA512',
          empty_binary_value: Digest::SHA512.new.digest
        )
      end
    end

    trait :crc32c do
      initialize_with do
        ChecksumAlgorithm.find_by(name: 'CRC32C') || ChecksumAlgorithm.create(
          name: 'CRC32C',
          empty_binary_value: Digest::CRC32c.new.digest
        )
      end
    end
  end
end
