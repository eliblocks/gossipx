class AddToolCallToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :tool_name, :string
    add_column :messages, :tool_call_id, :string
    add_column :messages, :tool_arguments, :jsonb
    add_column :messages, :thinking, :text
    add_column :messages, :thinking_signature, :text
  end
end
