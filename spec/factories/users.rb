# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:uid) { |n| "tester#{n}" }
    sequence(:email) { |n| "tester#{n}@example.com" }
    password { 'test_password' }

    trait :admin do
      is_admin { true }
    end
  end
end
