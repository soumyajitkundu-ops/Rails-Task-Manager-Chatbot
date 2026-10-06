module Mcp
  class ServerBuilder
    def self.build(user)
      tools = [
        Mcp::Tools::ListTodos,
        Mcp::Tools::ListAllTodos,
        Mcp::Tools::CreateTodo,
        Mcp::Tools::BulkCreateTodos,
        Mcp::Tools::UpdateTodo,
        Mcp::Tools::DeleteTodo
      ]
      prompts = [ Mcp::Prompts::TodoAssistantPrompt ]
      resources = [ Mcp::Resources::TodosResource ]

      server = MCP::Server.new(
        name: "todo_mcp_server", 
        tools: tools,
        prompts: prompts,
        resources: resources
      )
      server.server_context = { current_user: user }
      server
    end
  end
end
