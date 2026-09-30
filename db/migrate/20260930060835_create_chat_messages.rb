class CreateChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_messages do |t|
      t.references :user, null: false, foreign_key: true

      t.text :user_message, null: false
      t.text :assistant_message, null: false

      t.timestamps
    end

    # Ordering is by created_at (ties broken by the auto-increment id); this index
    # makes "fetch this user's messages in order" cheap as the table grows.
    add_index :chat_messages, [ :user_id, :created_at ]
  end
end
