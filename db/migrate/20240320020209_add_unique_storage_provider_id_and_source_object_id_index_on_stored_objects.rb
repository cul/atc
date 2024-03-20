class AddUniqueStorageProviderIdAndSourceObjectIdIndexOnStoredObjects < ActiveRecord::Migration[7.1]
  def change
    add_index(:stored_objects, [:storage_provider_id, :source_object_id], unique: true)
  end
end
