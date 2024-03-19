# frozen_string_literal: true

FactoryBot.define do
  factory :source_object do
    path { Rails.root.join('spec/fixtures/files/sample.jpg') }
    object_size { 1_259_574 }

    trait :with_zero_byte_object_size do
      object_size { 0 }
    end

    trait :with_checksum do
      fixity_checksum_algorithm { association :checksum_algorithm, :sha256 }
      fixity_checksum_value { Digest::SHA256.digest('A' * object_size) }
    end
  end
end
