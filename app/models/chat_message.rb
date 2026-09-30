# app/models/chat_message.rb
# One row per chat turn (user message + final assistant answer), in the order they happened.
# This is the durable, user-facing transcript — separate from ChatMemory, which is the AI's
# own working context and gets summarized/evicted over time. Rows here are never edited or
# deleted by the app; only AiChatService creates them, and only after the final answer for a
# turn is known.
class ChatMessage < ApplicationRecord
  belongs_to :user

  validates :user_message, presence: true
  validates :assistant_message, presence: true

  scope :chronological, -> { order(:created_at, :id) }
end
