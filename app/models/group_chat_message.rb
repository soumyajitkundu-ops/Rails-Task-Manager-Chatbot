class GroupChatMessage < ApplicationRecord
  belongs_to :owner, class_name: "User", optional: true

  validates :text, presence: true

  after_create_commit :broadcast_message

  scope :newest_first, -> { order(id: :desc) }

  def as_group_chat_json
    { text: text, id: id, ownerid: owner_id || -1, ownername: owner&.name || "AI" }
  end

  private

  def broadcast_message
    ActionCable.server.broadcast("group_chat", as_group_chat_json)
  end
end
