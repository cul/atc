# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    uid { 'tester ' }
    email { 'tester@example.com' }
    password { 'test_password' }
  end
end
