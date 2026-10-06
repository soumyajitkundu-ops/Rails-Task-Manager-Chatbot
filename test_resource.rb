require 'mcp'
class MyResource < MCP::Resource
  uri "todos://current-user"
  resource_name "Current User Todos"
  def self.contents(server_context: {})
    [ MCP::Resource::TextContents.new(uri: "todos://current-user", text: "Some todos", mime_type: 'text/plain') ]
  end
end
server = MCP::Server.new(name: 'a', version: '1', resources: [MyResource])
puts server.handle_json({jsonrpc: '2.0', id: 1, method: 'resources/read', params: { uri: 'todos://current-user' }}.to_json)
