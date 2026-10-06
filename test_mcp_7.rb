require "mcp"
class ExampleTool < MCP::Tool
  description "A simple example tool"
  input_schema(properties: { message: { type: "string" } }, required: ["message"])
  def self.call(message:, server_context:)
    user = server_context[:user_id]
    MCP::Tool::Response.new([{ type: "text", text: "Hello! User: #{user}, Message: #{message}" }])
  end
end

server = MCP::Server.new(name: "example_server", tools: [ExampleTool])
server.server_context = { user_id: 42 }
req2 = { "jsonrpc" => "2.0", "method" => "tools/call", "id" => 2, "params" => { "name" => "example_tool", "arguments" => { "message" => "Test" } } }.to_json
puts server.handle_json(req2)
