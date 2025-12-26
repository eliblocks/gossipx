class AddFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, default: "user", null: false
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :instagram_id, :string
    add_column :users, :instagram_username, :string
  end
end