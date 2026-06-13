Rails.application.routes.draw do
  resource :session, only: %i[new destroy]
  get "/auth/discord/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  resources :articles do
    resources :revisions, only: %i[index show] do
      post :restore, on: :member
    end
    resources :comments, only: :create
    resources :taggings, only: :create
  end
  resources :comments, only: :destroy
  resources :tags, only: %i[index show create destroy]
  resources :activities, only: :index
  get "chronicle", to: "chronicle#index"
  get "about", to: "about#show"
  resources :users, only: %i[show index]
  resource :account, only: %i[edit update]
  get "search", to: "search#index"
  get "stats", to: "stats#index"
  resources :materials do
    get "pdf", on: :member, to: "materials/pdf#show"
    resource :transcription, only: %i[show edit update] do
      resources :revisions, only: %i[index show], controller: "transcription_revisions"
    end
    resources :comments, only: :create
    resources :taggings, only: :create
  end
  get "transcriptions", to: "transcriptions#index"
  resources :uploads, only: :create
  root "home#index"
  resource :settings, only: %i[edit update]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
