module Mcp
  module Tools
    class UpdateTodo < MCP::Tool
      description "Update an existing todo belonging to the user."
      input_schema(
        properties: {
          id: { type: "integer" },
          task: { type: ["string", "null"] },
          description: { type: ["string", "null"] },
          priority: { type: ["integer", "null"] }
        },
        required: ["id"]
      )

      def self.call(id:, task: nil, description: nil, priority: nil, server_context:)
        user = server_context[:current_user]
        todo = user.todos.find_by(id: id)
        return MCP::Tool::Response.new([{ type: "text", text: "Todo not found or unauthorized." }], error: true) unless todo

        todo.task = task if task
        todo.description = description if description
        todo.priority = priority if priority

        if todo.save
          MCP::Tool::Response.new([{ type: "text", text: "Successfully updated todo ID: #{todo.id}" }])
        else
          MCP::Tool::Response.new([{ type: "text", text: "Failed: #{todo.errors.full_messages.join(', ')}" }], error: true)
        end
      end
    end
  end
end
