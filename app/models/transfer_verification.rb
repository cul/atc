# frozen_string_literal: true

class TransferVerification < ApplicationRecord
  belongs_to :object_transfer
  belongs_to :checksum_algorithm
  validates :checksum_value, presence: { strict: true }

  # TODO: Uncomment this line when VerifiedTransferValidator exists
  # validates_with VerifiedTransferValidator
end
