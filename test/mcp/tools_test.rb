require "test_helper"

class McpToolsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.todos.create!(task: "Test Task", description: "Desc", priority: 1) if @user.todos.empty?
    @server = Mcp::ServerBuilder.build(@user)
  end

  test "server initializes and tools are exposed" do
    assert_not_nil @server
    assert_includes @server.tools.keys, "list_todos"
    assert_includes @server.tools.keys, "create_todo"
    assert_includes @server.tools.keys, "bulk_create_todos"
    assert_includes @server.tools.keys, "update_todo"
    assert_includes @server.tools.keys, "delete_todo"
  end

  test "list_todos returns only user's todos" do
    result = Mcp::Tools::ListTodos.call(priority: nil, query: nil, server_context: { current_user: @user })
    assert_match(/Task:/, result.content.first[:text])
  end

  test "create_todo creates a todo for current user" do
    assert_difference('@user.todos.count', 1) do
      Mcp::Tools::CreateTodo.call(task: "Test MCP", description: "Learn MCP", priority: 9, server_context: { current_user: @user })
    end
  end

  test "bulk_create_todos creates multiple todos" do
    todos_payload = [
      { "task" => "Task A", "priority" => 1 },
      { "task" => "Task B", "priority" => 2 }
    ]
    assert_difference('@user.todos.count', 2) do
      Mcp::Tools::BulkCreateTodos.call(todos: todos_payload, server_context: { current_user: @user })
    end
  end

  test "update_todo updates user's todo" do
    todo = @user.todos.first
    Mcp::Tools::UpdateTodo.call(id: todo.id, task: "Updated Task", server_context: { current_user: @user })
    assert_equal "Updated Task", todo.reload.task
  end

  test "delete_todo deletes user's todo" do
    todo = @user.todos.first
    assert_difference('@user.todos.count', -1) do
      Mcp::Tools::DeleteTodo.call(id: todo.id, server_context: { current_user: @user })
    end
  end
  test "list_all_todos fails for non-admin" do
    result = Mcp::Tools::ListAllTodos.call(server_context: { current_user: @user })
    assert result.to_h[:isError]
    assert_match(/Unauthorized/, result.to_h[:content].first[:text])
  end

  test "list_all_todos succeeds for admin" do
    admin = users(:two)
    admin.update!(role: "admin")
    
    result = Mcp::Tools::ListAllTodos.call(server_context: { current_user: admin })
    assert_not result.to_h[:isError]
  end
end
