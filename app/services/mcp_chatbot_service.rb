class McpChatbotService
  def initialize(user)
    @user = user
    @groq_client = GroqClient.new
    @mcp_server = Mcp::ServerBuilder.build(user)
  end

  def call(messages)
    # messages is an array of { role: "user" | "assistant", content: "..." }
    # Fetch the system prompt from the MCP server
    prompt_req = { jsonrpc: "2.0", method: "prompts/get", id: 1, params: { name: "todo_assistant", arguments: {} } }.to_json
    prompt_resp = JSON.parse(@mcp_server.handle_json(prompt_req))
    prompt_text = prompt_resp.dig("result", "messages", 0, "content", "text")
    
    system_prompt = {
      role: "system",
      content: prompt_text || "You are a highly capable todo management assistant."
    }
    
    sanitized_messages = messages.map do |msg|
      msg.select { |k, _| %w[role content name tool_call_id tool_calls].include?(k.to_s) }
    end
    
    # Sliding window: keep only the last 5 messages to save tokens and prevent context limit issues
    recent_messages = sanitized_messages.last(5)
    
    current_messages = [system_prompt] + recent_messages
    
    # Extract tools from the MCP server to send to Groq
    # We call MCP tools/list to get the schema
    list_req = { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json
    list_resp = JSON.parse(@mcp_server.handle_json(list_req))
    mcp_tools = list_resp.dig("result", "tools") || []
    
    # Transform MCP tool schemas to Groq / OpenAI tool schemas
    groq_tools = mcp_tools.map do |t|
      {
        type: "function",
        function: {
          name: t["name"],
          description: t["description"],
          parameters: t["inputSchema"]
        }
      }
    end
    
    # 1. Ask Groq
    response = @groq_client.tool_chat(current_messages, groq_tools)
    
    if response["error"]
      return { error: response.dig("error", "message") || "Groq API error" }
    end
    
    message = response.dig("choices", 0, "message")
    
    # If Groq decides to call a tool
    if message["tool_calls"]
      tool_calls = message["tool_calls"]
      
      # We just process the first one for simplicity, or all of them
      tool_call = tool_calls.first
      function_name = tool_call.dig("function", "name")
      arguments = JSON.parse(tool_call.dig("function", "arguments")) rescue {}
      
      # Execute on MCP server
      call_req = {
        jsonrpc: "2.0",
        method: "tools/call",
        id: 2,
        params: {
          name: function_name,
          arguments: arguments
        }
      }.to_json
      
      call_resp = JSON.parse(@mcp_server.handle_json(call_req))
      
      # Extract result text
      is_error = call_resp.dig("result", "isError") || false
      contents = call_resp.dig("result", "content") || []
      result_text = contents.map { |c| c["text"] }.join("\n")
      
      # Append tool response to messages
      current_messages << message # The assistant's tool call
      current_messages << {
        role: "tool",
        tool_call_id: tool_call["id"],
        content: result_text
      }
      
      # 2. Ask Groq again with the tool result
      final_response = @groq_client.tool_chat(current_messages, groq_tools)
      final_message = final_response.dig("choices", 0, "message")
      
      return {
        role: "assistant",
        content: final_message["content"],
        tool_used: function_name
      }
    else
      # Just a normal text response
      return {
        role: "assistant",
        content: message["content"]
      }
    end
  rescue => e
    Rails.logger.error "McpChatbotService error: #{e.message}\n#{e.backtrace.join("\n")}"
    { error: "Internal server error: #{e.message}" }
  end
end
