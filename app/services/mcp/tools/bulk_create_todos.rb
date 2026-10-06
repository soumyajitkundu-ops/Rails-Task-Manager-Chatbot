module Mcp
  module Tools
    class BulkCreateTodos < MCP::Tool
      description "Bulk create multiple todos for the user."
      input_schema(
        properties: {
          todos: {
            type: "array",
            items: {
              type: "object",
              properties: {
                task: { type: "string" },
                description: { type: ["string", "null"] },
                priority: { type: ["integer", "null"] }
              },
              required: ["task"]
            }
          }
        },
        required: ["todos"]
      )

      def self.call(todos:, server_context:)
        user = server_context[:current_user]
        created = []
        failed = []

        ActiveRecord::Base.transaction do
          todos.each do |t|
            todo = user.todos.build(task: t["task"], description: t["description"], priority: t["priority"] || 5)
            if todo.save
              created << todo
            else
              failed << { task: t["task"], error: todo.errors.full_messages.join(', ') }
            end
          end
        end

        result = {
          created: created.map { |t| { id: t.id, task: t.task } },
          failed: failed
        }
        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      end
    end
  end
end
