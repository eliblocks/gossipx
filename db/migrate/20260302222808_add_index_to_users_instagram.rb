class AddIndexToUsersInstagram < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :instagram_id, unique: true
    add_index :users, :instagram_username, unique: true
  end
end
