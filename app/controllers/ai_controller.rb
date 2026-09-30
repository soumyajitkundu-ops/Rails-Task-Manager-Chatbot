# app/controllers/ai_controller.rb
class AiController < ApplicationController
  before_action :authenticate_user!

  CHAT_MESSAGE_FIELDS = [ :id, :user_id, :user_message, :assistant_message, :created_at ].freeze

  # POST /ai/chat
  # The ONLY endpoint that ever creates a ChatMessage row, and only after AiChatService has
  # produced the final answer (see AiChatService#call / #log_chat_message).
  def chat
    answer = AiChatService.new(current_user).call(params[:message])

    render json: {
      answer: answer
    }
  end

  # GET /ai/chats
  # Read-only: returns this user's persisted chat transcript, oldest first. Admins may pass
  # ?user_id= to view another user's transcript (same convention as TodosController).
  def chats
    scope = if current_user.role == "admin" && params[:user_id].present?
      ChatMessage.where(user_id: params[:user_id])
    else
      current_user.chat_messages
    end

    render json: {
      messages: scope.chronological.as_json(only: CHAT_MESSAGE_FIELDS)
    }
  end

  # DELETE /ai/memory
  # Kills this user's pending jobs, removes their session from the map,
  # then deletes their snapshot row from the database. Does NOT touch chat_messages:
  # that's the durable transcript, separate from the AI's working memory.
  def clear_memory
    ChatMemory.clear(current_user.id)

    render json: { message: "Chat memory cleared" }
  end
end
