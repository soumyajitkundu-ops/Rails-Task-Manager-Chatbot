module Mcp
  module Tools
    class DeleteTodo < MCP::Tool
      description "Delete an existing todo belonging to the user."
      input_schema(
        properties: {
          id: { type: "integer" }
        },
        required: ["id"]
      )

      def self.call(id:, server_context:)
        user = server_context[:current_user]
        todo = user.todos.find_by(id: id)
        return MCP::Tool::Response.new([{ type: "text", text: "Todo not found or unauthorized." }], error: true) unless todo

        if todo.destroy
          MCP::Tool::Response.new([{ type: "text", text: "Successfully deleted todo ID: #{id}" }])
        else
          MCP::Tool::Response.new([{ type: "text", text: "Failed to delete todo." }], error: true)
        end
      end
    end
  end
end
