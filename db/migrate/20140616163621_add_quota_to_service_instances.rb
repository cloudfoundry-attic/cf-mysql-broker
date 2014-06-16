class AddQuotaToServiceInstances < ActiveRecord::Migration
  def change
    add_column :service_instances, :max_storage_mb, :integer, null: false, default: 0
    add_index :service_instances, :guid
    add_index :service_instances, :plan_guid
  end
end
