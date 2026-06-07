class AddTwitterFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :twitter_id, :string
    add_column :users, :twitter_username, :string
    add_index :users, :twitter_id, unique: true
    add_index :users, :twitter_username, unique: true
  end
end
