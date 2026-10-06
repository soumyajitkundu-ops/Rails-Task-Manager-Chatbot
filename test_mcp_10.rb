require "mcp"

class TodosCurrentUser < MCP::Resource
  uri "todos://current-user"
  title "Current User Todos"
  description "The current user's details and todos"

  def self.read(uri, server_context:)
    data = { user: { id: 42, name: "test" }, todos: [] }
    # Let's just return a plain hash, the gem's read usually returns contents
    # Let's look at mcp/resource/contents.rb
    [MCP::Resource::TextContent.new(uri: uri, text: data.to_json, mime_type: "application/json")]
  end
end

class TodoAssistant < MCP::Prompt
  description "Todo management assistant prompt"

  def self.get(arguments:, server_context:)
    # Prompt get typically returns messages
    [MCP::Prompt::Message.new(role: "user", content: MCP::Content::Text.new(text: "Hello"))]
  end
end

server = MCP::Server.new(name: "example", resources: [TodosCurrentUser], prompts: [TodoAssistant])
puts server.resources.keys.inspect
puts server.prompts.keys.inspect
