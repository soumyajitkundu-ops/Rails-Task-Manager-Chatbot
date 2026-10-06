require 'mcp'
class MyPrompt < MCP::Prompt
  prompt_name "todo_assistant"
  description "A test prompt"
  def self.template(arguments, server_context: {})
    MCP::Prompt::Result.new(description: "hello", messages: [ MCP::Prompt::Message.new(role: "user", content: MCP::Content::Text.new("Hello")) ])
  end
end
server = MCP::Server.new(name: 'a', version: '1', prompts: [MyPrompt])
puts server.handle_json({jsonrpc: '2.0', id: 1, method: 'prompts/get', params: { name: 'todo_assistant', arguments: {} }}.to_json)
