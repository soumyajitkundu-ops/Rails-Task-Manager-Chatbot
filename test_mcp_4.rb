require "mcp"
puts MCP.constants.inspect
puts MCP::Client.constants.inspect if defined?(MCP::Client)
puts MCP::Server.constants.inspect if defined?(MCP::Server)
