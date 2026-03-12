require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users

  get "up" => "rails/health#show", as: :rails_health_check

  root "application#index"

  mount Sidekiq::Web => "/sidekiq"

  resources :users do
    patch "reset"
    resources :messages, only: [ :create, :destroy ]
    collection do
      post "generate"
    end
  end

  get "/messages", to: "messages#index"

  get "/webhooks/instagram", to: "webhooks#verify_instagram"
  post "/webhooks/instagram", to: "webhooks#instagram"
  get "/webhooks/whatsapp", to: "webhooks#verify_whatsapp"
  post "/webhooks/whatsapp", to: "webhooks#whatsapp"
  get "/webhooks/messenger", to: "webhooks#verify_messenger"
  post "/webhooks/messenger", to: "webhooks#messenger"
  get "/webhooks/twitter", to: "webhooks#verify_twitter"
  post "/webhooks/twitter", to: "webhooks#twitter"


  authenticate :user, ->(user) { user.role == "admin" } do
    mount GoodJob::Engine => "good_job"
  end
end
