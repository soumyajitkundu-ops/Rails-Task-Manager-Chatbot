require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
  end

  test "should get chat response" do
    # Simple monkeypatch for testing
    GroqClient.class_eval do
      alias_method :original_tool_chat, :tool_chat rescue nil
      def tool_chat(messages, tools)
        { "choices" => [ { "message" => { "content" => "I can help with that.", "tool_calls" => nil } } ] }
      end
    end

    ApplicationController.class_eval do
      alias_method :original_decoded_token, :decoded_token rescue nil
      def decoded_token
        { user_id: User.first.id }
      end
    end

    post "/mcp/chat", params: { messages: [{ role: "user", content: "hello" }] }
    assert_response :success
    assert_equal "I can help with that.", JSON.parse(response.body)["content"]
  ensure
    ApplicationController.class_eval do
      alias_method :decoded_token, :original_decoded_token rescue nil
    end
    GroqClient.class_eval do
      alias_method :tool_chat, :original_tool_chat rescue nil
    end
  end
end
