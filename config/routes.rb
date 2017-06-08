Rails.application.routes.draw do
  devise_for :users, controllers: {omniauth_callbacks: "users/omniauth_callbacks"}

  get "dashboard#index", to: "users/dashboard#index"

  root "users/dashboard#index"

  resources :messages
end
