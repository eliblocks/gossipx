class AddProviderToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :provider, :string
  end
end
