module Mcp
  module Resources
    class TodosResource < MCP::Resource
      uri "todos://current-user"
      resource_name "Current User Todos"
      
      def self.contents(server_context: {})
        user = server_context[:current_user]
        return [ MCP::Resource::TextContents.new(uri: "todos://current-user", text: "Unauthorized", mime_type: 'text/plain') ] unless user

        data = {
          user: {
            id: user.id,
            name: user.name,
            age: user.age,
            role: user.role
          },
          todos: user.todos.map { |t| { id: t.id, task: t.task, priority: t.priority, description: t.description } }
        }
        [ MCP::Resource::TextContents.new(uri: "todos://current-user", text: data.to_json, mime_type: 'application/json') ]
      end
    end
  end
end
