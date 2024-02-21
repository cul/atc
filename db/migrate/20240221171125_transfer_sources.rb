class TransferSources < ActiveRecord::Migration[7.1]
  def change
    create_table :repositories do |t|
      t.string :name
      t.timestamps
    end
    create_table :transfer_sources do |t|
      t.string :path, null: false
      t.binary :path_hash, limit: 32, null: false
      t.bigint :object_size, null: false
      t.datetime :on_prem_deleted, null: true
      t.references :repository, null: true

      t.timestamps
    end
    add_index(:transfer_sources, :path_hash, unique: true)
  end
end
