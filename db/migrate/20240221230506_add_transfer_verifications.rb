class AddTransferVerifications < ActiveRecord::Migration[7.1]
  def change
    create_table :transfer_verifications do |t|
      t.string :checksum_value, null: false
      t.references :checksum_algorithm, null: false
      t.integer :checksum_chunk_size, null: true
      t.bigint :object_size, null: false
      t.references :object_transfer, null: false
      t.timestamps
    end
  end
end
