module Mcp
  module Tools
    class CreateTodo < MCP::Tool
      description "Create a new todo for the user."
      input_schema(
        properties: {
          task: { type: "string" },
          description: { type: ["string", "null"] },
          priority: { type: ["integer", "null"] }
        },
        required: ["task"]
      )

      def self.call(task:, description: nil, priority: 5, server_context:)
        user = server_context[:current_user]
        todo = user.todos.build(task: task, description: description, priority: priority)
        if todo.save
          MCP::Tool::Response.new([{ type: "text", text: "Successfully created todo ID: #{todo.id}" }])
        else
          # Using is_error keyword instead of isError for the gem (or just text).
          # Actually MCP::Tool::Response.new([], error: true) works based on standard gem usage.
          MCP::Tool::Response.new([{ type: "text", text: "Failed: #{todo.errors.full_messages.join(', ')}" }], error: true)
        end
      end
    end
  end
end
