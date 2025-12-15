Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # SaumonNet health check endpoints
  get "health" => "health#show", as: :health_check
  get "health/saumon_net" => "health#saumon_net", as: :saumon_net_health_check
  get "health/imports" => "health#imports", as: :imports_health_check
  get "health/api" => "health#api", as: :api_health_check
  get "health/queues" => "health#queues", as: :queues_health_check
  get "health/events" => "health#events", as: :events_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
