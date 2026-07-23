class CreateCsvExportsAndAddIsAdminToUsers < ActiveRecord::Migration[7.1]  
  def change
    create_table :csv_exports do |t|
      t.string :path_to_csv_file, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps null: false
    end

    change_table :users do |t|
      t.boolean :is_admin, default: false, null: false
    end
  end
end
