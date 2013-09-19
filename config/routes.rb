CfMysqlBroker::Application.routes.draw do
  namespace :v2 do
    resource :catalog, only: [:show]

    resources :service_instances, only: [:update, :destroy]

    resources :service_bindings, only: [:update, :destroy]
  end
end

