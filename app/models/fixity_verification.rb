# frozen_string_literal: true

class FixityVerification < ApplicationRecord
  belongs_to :source_object
  belongs_to :stored_object

  enum status: { pending: 0, failure: 1, success: 2 }

  # Some db backends don't enforce a limit on binary field length,
  # so the limit below is meant to ensure that we don't ever
  # accidentally add a larger value. Make sure to update this
  # value if the database limit ever changes.
  validates :transfer_checksum_value, length: { maximum: 4 }
  validates_with TransferChecksumValidator
end
