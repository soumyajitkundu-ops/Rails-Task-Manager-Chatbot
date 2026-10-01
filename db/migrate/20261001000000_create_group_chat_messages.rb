class CreateGroupChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :group_chat_messages do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.text :text, null: false

      t.timestamps
    end

    add_index :group_chat_messages, :created_at
  end
end
