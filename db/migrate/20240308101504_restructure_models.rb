class RestructureModels < ActiveRecord::Migration[7.1]
  def change
    rename_table :transfer_sources, :source_objects
    rename_table :object_transfers, :stored_objects
    drop_table :transfer_verifications

    change_table :source_objects do |t|
      t.references :fixity_checksum_algorithm, null: true, index: true, foreign_key: { to_table: :checksum_algorithms }
      # Need a length of 64 for this column to hold SHA512 checksums, which are 64 bytes (512 bits)
      t.binary :fixity_checksum_value, limit: 64, null: true, index: true
    end

    change_table :stored_objects do |t|
      t.references :transfer_checksum_algorithm, null: true, index: true, foreign_key: { to_table: :checksum_algorithms }
      # Need a length of 4 for this column to hold CRC32C checksums, which are 4 bytes (32 bits)
      t.binary :transfer_checksum_value, limit: 4, null: true, index: true
      t.integer :transfer_checksum_chunk_size, null: true, index: true
      t.rename :transfer_source_id, :source_object_id
    end

    create_table :pending_transfers do |t|
      t.references :transfer_checksum_algorithm, null: false, index: true, foreign_key: { to_table: :checksum_algorithms }
      # Need a length of 4 for this column to hold CRC32C checksums, which are 4 bytes (32 bits)
      t.binary :transfer_checksum_value, limit: 4, null: false
      t.integer :transfer_checksum_chunk_size, null: true
      t.references :storage_provider, null: false, index: true
      t.references :source_object, null: false, index: true
      t.integer :status, null: false, default: 0 # pending / failure (and no need for success, since successful rows get converted into stored_object rows)
      t.text :error_message, null: true
      t.timestamps
    end

    create_table :fixity_verifications do |t|
      t.references :source_object, null: false, index: true
      t.references :stored_object, null: false, index: true
      t.integer :status, null: false, default: 0, index: true # pending / success / failure
      t.timestamps
    end

    change_table :checksum_algorithms do |t|
      t.change :empty_value, :binary
    end

    add_index(:pending_transfers, [:source_object_id, :storage_provider_id], unique: true)
  end
end
