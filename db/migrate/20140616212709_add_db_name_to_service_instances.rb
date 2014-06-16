class AddDbNameToServiceInstances < ActiveRecord::Migration
  def change
    add_column :service_instances, :db_name, :string
    add_index :service_instances, :db_name

    ServiceInstance.all.each do |instance|
      instance.db_name = ServiceInstanceManager.database_name_from_service_instance_guid(instance.guid)
      instance.save
    end
  end
end
