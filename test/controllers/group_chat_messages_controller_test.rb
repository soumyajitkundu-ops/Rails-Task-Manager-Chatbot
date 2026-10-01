require "test_helper"

class GroupChatMessagesControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @user = User.create!(name: "group-chat-#{SecureRandom.hex(4)}", age: 30, password: "password")
    sign_in(@user)
  end

  test "creates a shared message with an automatic id and owner" do
    assert_difference("GroupChatMessage.count", 1) do
      post group_chat_messages_url, params: { text: "Hello everyone" }, as: :json
    end

    assert_response :created
    message = response.parsed_body.fetch("messages").first
    assert_equal "Hello everyone", message.fetch("text")
    assert_equal @user.id, message.fetch("ownerid")
    assert_equal @user.name, message.fetch("ownername")
    assert message.fetch("id").positive?
  end

  test "returns five newest messages and pages back in chronological order" do
    7.times do |index|
      @user.group_chat_messages.create!(text: "Message #{index + 1}")
    end

    get group_chat_messages_url

    assert_response :success
    first_page = response.parsed_body
    assert_equal [ "Message 3", "Message 4", "Message 5", "Message 6", "Message 7" ],
                 first_page.fetch("messages").map { |message| message.fetch("text") }
    assert first_page.fetch("has_more")

    get group_chat_messages_url, params: { before_id: first_page.fetch("messages").first.fetch("id") }

    assert_response :success
    older_page = response.parsed_body
    assert_equal [ "Message 1", "Message 2" ], older_page.fetch("messages").map { |message| message.fetch("text") }
    assert_not older_page.fetch("has_more")
  end

  test "messages are visible to every authenticated user" do
    @user.group_chat_messages.create!(text: "Shared")
    other_user = User.create!(name: "group-chat-#{SecureRandom.hex(4)}", age: 30, password: "password")
    sign_in(other_user)

    get group_chat_messages_url

    assert_response :success
    assert_equal [ "Shared" ], response.parsed_body.fetch("messages").map { |message| message.fetch("text") }
  end

  test "@AI responds using the five previous group messages" do
    6.times do |index|
      @user.group_chat_messages.create!(text: "Earlier message #{index + 1}")
    end

    groq_client = Object.new
    captured_messages = nil
    groq_client.define_singleton_method(:chat) do |messages|
      captured_messages = messages
      { "choices" => [ { "message" => { "content" => '{"answer":"Hello from AI"}' } } ] }
    end

    prompt = @user.group_chat_messages.create!(text: "@AI what do you think?")
    ai_message = nil
    assert_difference("GroupChatMessage.count", 1) do
      ai_message = GroupChatAiService.new(prompt, groq_client: groq_client).call
    end

    assert_equal "Hello from AI", ai_message.text
    assert_nil ai_message.owner_id
    assert_equal({ text: "Hello from AI", id: ai_message.id, ownerid: -1, ownername: "AI" }, ai_message.as_group_chat_json)

    transcript = captured_messages.last.fetch(:content)
    assert_includes captured_messages.first.fetch(:content), "Return a JSON object"
    assert_includes captured_messages.first.fetch(:content), "Never search for tasks, todos"
    assert_includes transcript, "#{@user.name}: Earlier message 2"
    assert_includes transcript, "Earlier message 6"
    assert_not_includes transcript, "Earlier message 1"
    assert_includes transcript, "#{@user.name}: @AI what do you think?"
  end

  test "@AI searches public questions and answers from evidence without task data" do
    groq_responses = [
      { "choices" => [ { "message" => { "content" => '{"answer":"","search_query":"weather in Kolkata today"}' } } ] },
      { "choices" => [ { "message" => { "content" => '{"answer":"Rain is expected today."}' } } ] }
    ]
    captured_prompts = []
    groq_client = Object.new
    groq_client.define_singleton_method(:chat) do |messages|
      captured_prompts << messages
      groq_responses.shift
    end

    search_queries = []
    search_client = Object.new
    search_client.define_singleton_method(:search) do |query|
      search_queries << query
      [ { title: "Weather forecast", snippet: "Rain is expected today." } ]
    end
    search_client.define_singleton_method(:ai_mode_answer) { |_query| nil }

    prompt = @user.group_chat_messages.create!(text: "@AI is it raining in Kolkata now?")
    ai_message = GroupChatAiService.new(prompt, groq_client: groq_client, search_client: search_client).call

    assert_equal "Rain is expected today.", ai_message.text
    assert_equal [ "weather in Kolkata today" ], search_queries
    assert_equal 2, captured_prompts.length
    assert_includes captured_prompts.last.first.fetch(:content), "ONLY the public evidence"
  end

  private

  def sign_in(user)
    post login_url, params: { name: user.name, password: "password" }, as: :json
    assert_response :success
  end
end
