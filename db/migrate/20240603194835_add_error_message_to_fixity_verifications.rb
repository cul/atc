class AddErrorMessageToFixityVerifications < ActiveRecord::Migration[7.1]
  def change
    add_column :fixity_verifications, :error_message, :text
  end
end
