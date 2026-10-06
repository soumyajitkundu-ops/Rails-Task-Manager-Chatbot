require "mcp"
require "json"

class ExampleTool < MCP::Tool
  description "A simple example tool"
  input_schema(properties: { message: { type: "string" } }, required: ["message"])
  def self.call(message:, server_context:)
    MCP::Tool::Response.new([{ type: "text", text: "Hello! Message: #{message}" }])
  end
end

server = MCP::Server.new(name: "example_server", tools: [ExampleTool])
# Let's see if handle_json is supported
req = { "jsonrpc" => "2.0", "method" => "tools/list", "id" => 1 }.to_json
puts server.handle_json(req) rescue puts $!

# Since handle takes a request Hash, let's look at how handle expects the request.
# Let's inspect MCP::Server#handle source if possible, or try symbols
req2 = { jsonrpc: "2.0", method: "tools/list", id: 2 }
puts server.respond_to?(:handle)
puts server.handle(req2) rescue puts $!
