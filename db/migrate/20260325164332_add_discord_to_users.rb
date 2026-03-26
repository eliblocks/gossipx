class AddDiscordToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :discord_id, :string
    add_column :users, :discord_username, :string
    add_column :users, :active_guild_id, :string
    add_column :users, :channel_id, :string

    add_index :users, :discord_id, unique: true
    add_index :users, :discord_username, unique: true
    add_index :users, :active_guild_id
  end
end
