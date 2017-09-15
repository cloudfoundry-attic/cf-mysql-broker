namespace :table_locks do

  desc "Update Table Lock Permissions"
  task :update_table_lock_permissions => :environment do
    TableLockManager.update_table_lock_permissions
  end

end
