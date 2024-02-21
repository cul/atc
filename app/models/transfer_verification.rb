class TransferVerification < ApplicationRecord
	belongs_to :object_transfer
	belongs_to :checksum_algorithm
	validates :checksum_value, presence: { strict: true }

	validates_with VerifiedTransferValidator
end