CfMysqlBroker::Application.routes.draw do
  namespace :v3 do
    get '', to: 'statuses#show'
  end
end
