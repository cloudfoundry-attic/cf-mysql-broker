namespace :broker do

  desc "Update size of existing service instances to match plans in Settings"
  task :sync_plans_in_db do
    require File.expand_path('../../../config/environment', __FILE__)
    ServiceInstanceManager.sync_service_instances
  end

  desc 'Update max user connections for all users to match plans in Settings'
  task :update_all_max_user_connections do
    require File.expand_path('../../../config/environment', __FILE__)
    ServiceBinding.update_all_max_user_connections
  end
end
