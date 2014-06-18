class AddDbNameToServiceInstances < ActiveRecord::Migration
  class ServiceInstance < ActiveRecord::Base
  end

  def change
    add_column :service_instances, :db_name, :string
    add_index :service_instances, :db_name

    ServiceInstance.find_each do |instance|
      instance.db_name = "cf_#{instance.guid.gsub('-', '_')}"
      instance.save
    end
  end
end
