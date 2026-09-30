class CreateChatMemorySnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_memory_snapshots do |t|
      # One durable snapshot row per user (unique index enforces it)
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      # core_data is deliberately NOT stored: it is rebuilt from users/todos on load
      t.text :summary
      t.json :learned_facts, null: false
      t.json :recent_turns, null: false
      t.json :priority_turns, null: false

      t.timestamps
    end
  end
end
