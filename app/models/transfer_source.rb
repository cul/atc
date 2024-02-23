# frozen_string_literal: true

require 'digest'

class TransferSource < ApplicationRecord
  belongs_to :repository, optional: true
  validates :path, presence: { strict: true }, on: :create

  validates_with PathValidator, on: :update
  validates_with PathHashValidator

  include PathHashes
end
