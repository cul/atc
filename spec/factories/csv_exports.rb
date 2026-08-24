# frozen_string_literal: true

FactoryBot.define do
  factory :csv_export do
    user
    status { :pending }
    export_paths { [{ bucket: 'test-bucket', keys: ['file.txt'], prefixes: [] }].to_json }
  end
end
