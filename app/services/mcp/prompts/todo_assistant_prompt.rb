module Mcp
  module Prompts
    class TodoAssistantPrompt < MCP::Prompt
      prompt_name "todo_assistant"
      description "Assistant for managing todos"
      
      def self.template(arguments, server_context: {})
        resource_data = Mcp::Resources::TodosResource.contents(server_context: server_context).first.text
        
        prompt_text = <<~TEXT
          You are a highly capable todo management assistant. Use the available MCP tools to help the user manage their todos. 
          When making tools calls, respond only with the tool call. If the user asks for their todos, call list_todos or use the provided resource context.
          Do not make up IDs. Confirm destructive operations.
          
          Here is the current resource data for the user:
          #{resource_data}
        TEXT

        MCP::Prompt::Result.new(
          description: "Instructs the model to act as a todo assistant with resource context",
          messages: [ 
            MCP::Prompt::Message.new(
              role: "user", 
              content: MCP::Content::Text.new(prompt_text)
            ) 
          ]
        )
      end
    end
  end
end
