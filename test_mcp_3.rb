require "mcp"
class ExampleTool < MCP::Tool
  description "A simple example tool"
  input_schema(properties: { message: { type: "string" } }, required: ["message"])
  def self.call(message:, server_context:)
    MCP::Tool::Response.new([{ type: "text", text: "Hello! Message: #{message}" }])
  end
end
server = MCP::Server.new(name: "example_server", tools: [ExampleTool])
req = { "jsonrpc" => "2.0", "method" => "tools/list", "id" => 1 }
puts server.handle(req).inspect
req2 = { "jsonrpc" => "2.0", "method" => "tools/call", "id" => 2, "params" => { "name" => "example_tool", "arguments" => { "message" => "Test" } } }
puts server.handle(req2).inspect
