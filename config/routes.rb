CfMysqlBroker::Application.routes.draw do
  resource :preview, only: [:show]

  namespace :v2 do
    resource :catalog, only: [:show]
    patch 'service_instances/:id' => 'service_instances#set_plan'
    resources :service_instances, only: [:update, :destroy] do
      resources :service_bindings, only: [:update, :destroy]
    end
  end

  namespace :manage do
    get 'auth/cloudfoundry/callback' => 'auth#create'
    get 'auth/failure' => 'auth#failure'
    resources :instances, only: [:show]
  end
end
