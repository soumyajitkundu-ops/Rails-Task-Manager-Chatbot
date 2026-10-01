class GroupChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "group_chat"
  end
end
