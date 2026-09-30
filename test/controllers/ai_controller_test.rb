require "test_helper"

class AiControllerTest < ActionDispatch::IntegrationTest
  test "should get chat" do
    get ai_chat_url
    assert_response :success
  end
end
