class McpController < ApplicationController
  before_action :authenticate_user!

  def chat
    messages = params[:messages] || []
    
    service = McpChatbotService.new(current_user)
    result = service.call(messages.as_json)
    
    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: result
    end
  end
end
