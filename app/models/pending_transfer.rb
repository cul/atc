# frozen_string_literal: true

class PendingTransfer < ApplicationRecord
  belongs_to :source_object
  belongs_to :storage_provider
  belongs_to :transfer_checksum_algorithm, class_name: 'ChecksumAlgorithm'

  include StoredObjectPathHashes

  enum status: { pending: 0, in_progress: 1, failure: 2 }

  # Some db backends don't enforce a limit on binary field length,
  # so the limit below is meant to ensure that we don't ever
  # accidentally add a larger value. Make sure to update this
  # value if the database limit ever changes.
  validates :transfer_checksum_value, length: { maximum: 4 }
  validates_with TransferChecksumValidator

  validates_with PendingTransfer::SourceObjectChecksumValidator
end
