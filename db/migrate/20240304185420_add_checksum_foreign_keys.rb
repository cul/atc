class AddChecksumForeignKeys < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :checksums, :transfer_sources
    add_foreign_key :checksums, :checksum_algorithms
    add_foreign_key :object_transfers, :transfer_sources
    add_foreign_key :object_transfers, :storage_providers
    add_foreign_key :transfer_verifications, :object_transfers
    add_foreign_key :transfer_verifications, :checksum_algorithms
  end
end
