class TodosController < ApplicationController
  before_action :authenticate_user!

  TODO_FIELDS = [ :id, :user_id, :task, :description, :priority, :created_at, :updated_at ].freeze

  # GET /me
  def me
    todos_scope = current_user.role == "admin" ? Todo.all : current_user.todos

    render json: {
      user: {
        id: current_user.id,
        name: current_user.name,
        age: current_user.age,
        role: current_user.role,
        created_at: current_user.created_at,
        updated_at: current_user.updated_at,
        todos: todos_scope.as_json(only: TODO_FIELDS)
      }
    }
  end

  # POST /todos
  def create
    todos = params[:todos]

    created_todos = todos.map do |todo_params|
      current_user.todos.create!(
        task: todo_params[:task],
        description: todo_params[:description],
        priority: todo_params[:priority]
      )
    end

    # Refresh only the todo snapshot; keep the conversation intact
    ChatMemory.refresh_core_data(current_user)

    render json: {
      message: "Todos created successfully",
      todos: created_todos.as_json(only: TODO_FIELDS)
    }, status: :created

  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PATCH /todos/:id
  def update
    todo = current_user.role == "admin" ? Todo.find(params[:id]) : current_user.todos.find(params[:id])

    if todo.update(todo_params)

      # Refresh the Todo owner's snapshot (crucial for admin edits)
      ChatMemory.refresh_core_data(todo.user)

      render json: { message: "Todo updated successfully", todo: todo.as_json(only: TODO_FIELDS) }
    else
      render json: { errors: todo.errors.full_messages }, status: :unprocessable_entity
    end

  rescue ActiveRecord::RecordNotFound
    render json: { error: "Todo not found or does not belong to current user" }, status: :not_found
  end

  private

  def todo_params
    params.permit(:task, :description, :priority)
  end
end
