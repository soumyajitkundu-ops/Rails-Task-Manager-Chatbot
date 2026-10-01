class AllowAiGroupChatMessages < ActiveRecord::Migration[8.1]
  def change
    change_column_null :group_chat_messages, :owner_id, true
  end
end
