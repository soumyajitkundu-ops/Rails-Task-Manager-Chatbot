require "mcp"

class ExampleResource < MCP::Resource
  uri "todos://current-user"
  title "Current User Todos"
  description "The current user's details and todos"

  def self.read(uri, server_context:)
    user = server_context[:current_user]
    data = { user: { id: 42, name: "test" }, todos: [] }
    MCP::Resource::Response.new([{ type: "text", text: data.to_json, mimeType: "application/json" }])
  end
end

class ExamplePrompt < MCP::Prompt
  name "todo_assistant"
  description "Todo management assistant prompt"

  def self.get(arguments:, server_context:)
    MCP::Prompt::Response.new([
      { role: "user", content: { type: "text", text: "Hello" } }
    ])
  end
end

server = MCP::Server.new(name: "example", resources: [ExampleResource], prompts: [ExamplePrompt])
puts server.resources.inspect
puts server.prompts.inspect
