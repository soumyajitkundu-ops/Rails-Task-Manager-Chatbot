Rails.application.routes.draw do
  post "ai/chat"
  get "ai/chats"
  delete "ai/clear_memory"

  post "/register", to: "sessions#register"
  post "/login",    to: "sessions#login"
  delete "/logout", to: "sessions#logout"

  get "/me", to: "todos#me"

  post "/todos", to: "todos#create"
  patch "/todos/:id", to: "todos#update"
end
