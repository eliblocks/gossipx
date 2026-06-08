class RemoveInstagramFacebookDiscordFromUsersAndMessages < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :instagram_id, :string
    remove_column :users, :instagram_username, :string
    remove_column :users, :facebook_id, :string
    remove_column :users, :facebook_username, :string
    remove_column :users, :discord_id, :string
    remove_column :users, :discord_username, :string
    remove_column :users, :active_guild_id, :string
    remove_column :users, :channel_id, :string
    remove_column :messages, :guild_id, :string
  end
end
