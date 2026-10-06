require "mcp"

class ExampleTool < MCP::Tool
  description "A simple example tool"
  input_schema(properties: { message: { type: "string" } }, required: ["message"])

  def self.call(message:, server_context:)
    MCP::Tool::Response.new([{ type: "text", text: "Hello! Message: #{message}" }])
  end
end

server = MCP::Server.new(name: "example_server", tools: [ExampleTool])
puts "Server tools:"
puts server.tools.inspect
