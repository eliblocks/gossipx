class AddFacebookToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :facebook_id, :string
    add_column :users, :facebook_username, :string

    add_index :users, :facebook_id, unique: true
    add_index :users, :facebook_username, unique: true
  end
end
