class AddStorageProvidersAndObjectTransfers < ActiveRecord::Migration[7.1]
  def change
    create_table :storage_providers do |t|
      t.integer :storage_type, null: false, index: true
      t.string :container_name, null: false, index: true
      t.timestamps
    end
    add_index(:storage_providers, [:storage_type, :container_name], unique: true)

    create_table :object_transfers do |t|
      t.string :path, null: false
      t.binary :path_hash, limit: 32, null: false
      t.references :transfer_source, null: false
      t.references :storage_provider, null: false
      t.timestamps
    end
    add_index(:object_transfers, [:storage_provider_id, :path_hash], unique: true)
  end
end
