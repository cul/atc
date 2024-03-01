# frozen_string_literal: true

require 'digest'

class TransferSource < ApplicationRecord
  include PathHashes

  belongs_to :repository, optional: true
  has_many :checksums
  validates :path, :path_hash, presence: { strict: true }, on: :create

  validates_with PathValidator, on: :update
  validates_with PathHashValidator
end
