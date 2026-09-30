# app/models/chat_memory_snapshot.rb
# Durable copy of a user's ChatMemory conversation state (one row per user).
class ChatMemorySnapshot < ApplicationRecord
  belongs_to :user

  # Insert-or-update the single snapshot row for a user.
  # The unique index on user_id guards against two writers creating duplicates.
  def self.persist!(user_id, attrs)
    record = find_or_initialize_by(user_id: user_id)
    record.assign_attributes(attrs)
    record.save!
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
