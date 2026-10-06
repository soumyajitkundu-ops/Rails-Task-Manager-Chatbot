require "mcp"

class TodosCurrentUser < MCP::Resource
  uri "todos://current-user"
  title "Current User Todos"
  description "The current user's details and todos"

  def self.read(uri:, server_context:)
    data = { user: { id: 42, name: "test" }, todos: [] }
    [MCP::Resource::TextContent.new(uri: uri, text: data.to_json, mime_type: "application/json")]
  end
end

class TodoAssistant < MCP::Prompt
  description "Todo management assistant prompt"

  def self.get(arguments:, server_context:)
    [MCP::Prompt::Message.new(role: "user", content: MCP::Content::Text.new(text: "Hello"))]
  end
end

server = MCP::Server.new(name: "example", resources: [TodosCurrentUser], prompts: [TodoAssistant])
puts server.handle_json({jsonrpc: "2.0", method: "resources/read", id: 1, params: { uri: "todos://current-user" } }.to_json)
puts server.handle_json({jsonrpc: "2.0", method: "prompts/get", id: 2, params: { name: "todo_assistant" } }.to_json)
