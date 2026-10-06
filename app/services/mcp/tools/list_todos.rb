module Mcp
  module Tools
    class ListTodos < MCP::Tool
      description "List the user's todos. Allows filtering by priority or query."
      input_schema(
        properties: {
          priority: { type: ["integer", "null"], description: "Filter by this priority (optional)" },
          query: { type: ["string", "null"], description: "Search query for task or description (optional)" }
        },
        required: []
      )

      def self.call(priority: nil, query: nil, server_context:)
        user = server_context[:current_user]
        todos = user.todos
        todos = todos.where(priority: priority) if priority
        if query.present?
          todos = todos.where("task LIKE :q OR description LIKE :q", q: "%#{query}%")
        end

        todo_texts = todos.map { |t| "ID: #{t.id} | Task: #{t.task} | Priority: #{t.priority} | Desc: #{t.description}" }
        response_text = todo_texts.any? ? todo_texts.join("\n") : "No todos found."
        MCP::Tool::Response.new([{ type: "text", text: response_text }])
      end
    end
  end
end
