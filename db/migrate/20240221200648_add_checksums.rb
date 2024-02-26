class AddChecksums < ActiveRecord::Migration[7.1]
  def change
    create_table :checksum_algorithms do |t|
      t.string :name, null: false
      t.string :empty_value, null: false
      t.timestamps
    end
    add_index(:checksum_algorithms, :name, unique: true)
    add_index(:checksum_algorithms, :empty_value, unique: true)

    create_table :checksums do |t|
      t.string :value, null: false
      t.references :checksum_algorithm, null: false
      t.references :transfer_source, null: false
      t.integer :chunk_size, null: true
      t.timestamps
    end
  end
end
