CfMysqlBroker::Application.routes.draw do
  namespace :v2 do
    resource :catalog, only: [:show]

    resource :service_instances, only: [:destroy]
    put '/service_instances/:id', to: 'service_instances#create'

    resource :service_bindings, only: [:destroy]
    put '/service_bindings/:id', to: 'service_bindings#create'

  end
end
