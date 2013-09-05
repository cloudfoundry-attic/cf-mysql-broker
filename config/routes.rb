CfMysqlBroker::Application.routes.draw do
  namespace :v2 do
    resource :catalog, only: [:show]
    resource :service_instances, only: [:create]
  end
end
