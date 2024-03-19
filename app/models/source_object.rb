# frozen_string_literal: true

class SourceObject < ApplicationRecord
  include PathHashes

  belongs_to :repository, optional: true
  belongs_to :fixity_checksum_algorithm, class_name: 'ChecksumAlgorithm', optional: true
  has_many :pending_transfers, inverse_of: :source_object, dependent: :destroy

  validates :path, :path_hash, presence: { strict: true }, on: :create
  validates :object_size, presence: true
  # Some db backends don't enforce a limit on binary field length,
  # so the limit below is meant to ensure that we don't ever
  # accidentally add a larger value. Make sure to update this
  # value if the database limit ever changes.
  validates :fixity_checksum_value, length: { maximum: 64 }

  validates_with PathValidator, on: :update
  validates_with PathHashValidator
  validates_with FixityChecksumValidator
end
