namespace :broker do

  desc "Update properties of existing service instances to match plans in Settings"
  task :sync_plans_in_db do
    require File.expand_path('../../../config/environment', __FILE__)
    ServiceInstanceManager.sync_service_instances
    ServiceBinding.update_all_max_user_connections
  end
end
