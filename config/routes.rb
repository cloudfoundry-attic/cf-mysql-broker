CfMysqlBroker::Application.routes.draw do
  namespace :v2 do
    resource :catalog, only: [:show]
  end
end
