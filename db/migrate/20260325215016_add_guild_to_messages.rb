class AddGuildToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :guild_id, :string

    add_index :messages, :guild_id
  end
end
