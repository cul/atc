class AddIsBackfilledEntryToStoredObjects < ActiveRecord::Migration[7.1]
  def change
    add_column :stored_objects, :is_backfilled_entry, :boolean, default: false
  end
end
