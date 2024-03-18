# frozen_string_literal: true

class PendingTransfer < ApplicationRecord
  belongs_to :source_object
  belongs_to :storage_provider
  belongs_to :transfer_checksum_algorithm, class_name: 'ChecksumAlgorithm'

  enum status: { pending: 0, failure: 1 }

  # Some db backends don't enforce a limit on binary field length,
  # so the limit below is meant to ensure that we don't ever
  # accidentally add a larger value. Make sure to update this
  # value if the database limit ever changes.
  validates :transfer_checksum_value, length: { maximum: 64 }
  validates_with TransferChecksumValidator
end
