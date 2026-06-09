Rails.application.routes.draw do
  devise_for :users, path: "auth"

  get "up" => "rails/health#show", as: :rails_health_check

  root "application#index"

  resources :users do
    patch "reset"
    resources :messages, only: [ :create, :destroy ]
    collection do
      post "generate"
    end
  end

  get "/messages", to: "messages#index"

  get "/webhooks/twitter", to: "webhooks#verify_twitter"
  post "/webhooks/twitter", to: "webhooks#twitter"

end
