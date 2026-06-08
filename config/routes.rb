Rails.application.routes.draw do
  devise_for :users

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

  authenticate :user, ->(user) { user.role == "admin" } do
    mount GoodJob::Engine => "good_job"
  end
end
