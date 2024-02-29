# frozen_string_literal: true

class StorageProvider < ApplicationRecord
  enum storage_type: { aws: 0, gcp: 1, cul: 2 }

  validates :storage_type, :container_name, presence: true
end
