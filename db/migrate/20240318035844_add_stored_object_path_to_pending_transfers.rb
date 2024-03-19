class AddStoredObjectPathToPendingTransfers < ActiveRecord::Migration[7.1]
  def change
    change_table :pending_transfers do |t|
      t.string :stored_object_path, null: true, limit: 1024 # 1024 bytes is the max length of an AWS or GCP bucket key
      t.binary :stored_object_path_hash, limit: 32, null: true
    end
  end
end
