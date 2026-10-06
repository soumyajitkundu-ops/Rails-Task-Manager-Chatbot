require "test_helper"

class AiControllerTest < ActionDispatch::IntegrationTest
  test "should get chat" do
    post ai_chat_url
    assert_response :unauthorized
  end
end
