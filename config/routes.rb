Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  post "ai/chat"
  get "ai/chats"
  delete "ai/clear_memory"

  get "group_chat/messages", to: "group_chat_messages#index"
  post "group_chat/messages", to: "group_chat_messages#create"

  get "readers_writers/state", to: "readers_writers#show"
  post "readers_writers/lock", to: "readers_writers#create"
  delete "readers_writers/lock", to: "readers_writers#destroy"

  post "/register", to: "sessions#register"
  post "/login",    to: "sessions#login"
  delete "/logout", to: "sessions#logout"

  get "/me", to: "todos#me"

  post "/todos", to: "todos#create"
  patch "/todos/:id", to: "todos#update"

  post "/mcp/chat", to: "mcp#chat"
end
