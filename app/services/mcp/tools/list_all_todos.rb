module Mcp
  module Tools
    class ListAllTodos < MCP::Tool
      description "List todos for all users. Only available to administrators. Allows filtering by user_id, priority, or query."
      input_schema(
        properties: {
          user_id: { type: ["integer", "null"], description: "Filter by user ID (optional)" },
          priority: { type: ["integer", "null"], description: "Filter by this priority (optional)" },
          query: { type: ["string", "null"], description: "Search query for task or description (optional)" }
        },
        required: []
      )

      def self.call(user_id: nil, priority: nil, query: nil, server_context:)
        user = server_context[:current_user]
        
        unless user&.role == "admin"
          return MCP::Tool::Response.new([{ type: "text", text: "Unauthorized: Only administrators can list all todos." }], error: true)
        end

        todos = Todo.all
        todos = todos.where(user_id: user_id) if user_id
        todos = todos.where(priority: priority) if priority
        if query.present?
          todos = todos.where("task LIKE :q OR description LIKE :q", q: "%#{query}%")
        end

        # Eager load user to avoid N+1 queries if we print the user's name, or just use user_id
        todos = todos.includes(:user)

        todo_texts = todos.map do |t|
          "Todo ID: #{t.id} | User ID: #{t.user_id} (Name: #{t.user&.name}) | Task: #{t.task} | Priority: #{t.priority} | Desc: #{t.description}"
        end
        
        response_text = todo_texts.any? ? todo_texts.join("\n") : "No todos found."
        MCP::Tool::Response.new([{ type: "text", text: response_text }])
      end
    end
  end
end
