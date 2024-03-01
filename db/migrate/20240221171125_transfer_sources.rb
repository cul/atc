class TransferSources < ActiveRecord::Migration[7.1]
  def change
    create_table :repositories do |t|
      t.string :name
      t.timestamps
    end
    create_table :transfer_sources do |t|
      t.string :path, null: false, limit: 4096 # 4096 is the max path length on a linux filesystem
      t.binary :path_hash, limit: 32, null: false
      t.bigint :object_size, null: false
      t.datetime :on_prem_deleted_at, null: true
      t.references :repository, null: true

      t.timestamps
    end
    add_index(:transfer_sources, :path_hash, unique: true)
  end
end
