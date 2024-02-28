# frozen_string_literal: true

require 'digest'

class ObjectTransfer < ApplicationRecord
  belongs_to :transfer_source
  belongs_to :storage_provider

  validates :path, :path_hash, presence: { strict: true }, on: :create
  validates_with PathValidator, on: :update
  validates_with PathHashValidator

  include PathHashes
end
