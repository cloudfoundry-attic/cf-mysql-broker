class AddDbNameToServiceInstances < ActiveRecord::Migration
  class ServiceInstance < ActiveRecord::Base
  end

  def up
    add_column :service_instances, :db_name, :string
    add_index :service_instances, :db_name

    ServiceInstance.find_each do |instance|
      instance.db_name = "cf_#{instance.guid.gsub('-', '_')}"
      instance.save
    end
  end

  def down
    remove_index :service_instances, :db_name
    remove_column :service_instances, :db_name
  end
end
