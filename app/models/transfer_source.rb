require 'digest'

class TransferSource < ApplicationRecord
	has_one :repository, required: false
	validates :path, presence: { strict: true }, on: :create

	validates_with PathValidator, on: :update
	validates_with PathHashValidator

	include PathHashes
end