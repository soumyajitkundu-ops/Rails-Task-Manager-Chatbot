class GroupChatMessagesController < ApplicationController
  before_action :authenticate_user!

  PAGE_SIZE = 5

  def index
    messages = GroupChatMessage.newest_first
    messages = messages.where("id < ?", params[:before_id]) if params[:before_id].present?
    page = messages.limit(PAGE_SIZE + 1).to_a

    render json: {
      messages: page.first(PAGE_SIZE).reverse.map(&:as_group_chat_json),
      has_more: page.length > PAGE_SIZE
    }
  end

  def create
    message = current_user.group_chat_messages.create(text: params[:text])

    if message.persisted?
      ai_message = GroupChatAiService.new(message).call if message.text.match?(/(?<!\w)@AI\b/i)
      messages = [ message, ai_message ].compact.map(&:as_group_chat_json)

      render json: { messages: messages }, status: :created
    else
      render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
