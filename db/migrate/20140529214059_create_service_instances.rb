class CreateServiceInstances < ActiveRecord::Migration
  class ServiceInstance < ActiveRecord::Base
  end

  class DatabaseNameToServiceInstanceGuidConverter
    DATABASE_PREFIX = 'cf_'.freeze

    def self.guid_from_database_name(database_name)
      guid = database_name.sub(DATABASE_PREFIX, '').gsub('_', '-')

      # MySQL database names are limited to [0-9,a-z,A-Z$_] and 64 chars
      if guid =~ /[^0-9,a-z,A-Z$-]+/
        raise 'Only ids matching [0-9,a-z,A-Z$-]+ are allowed'
      end

      guid
    end
  end

  def up
    services = Settings['services']
    plans = services.first['plans']
    plan_guid = plans.first['id']

    raise "Migration cannot be performed: no service plans found" unless (1 == services.length && plans.length >= 1 )
    puts "Migration will associate existing service instances with the first service plan from the catalog (id: #{plan_guid})" unless (1 == services.length && 1 == plans.length)

    create_table :service_instances do |t|
      t.string :guid
      t.string :plan_guid
    end

    schema_names = connection.select("SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE schema_name LIKE 'cf\\_%'").rows.flatten
    schema_names.each do |name|
      guid = DatabaseNameToServiceInstanceGuidConverter.guid_from_database_name(name)
      ServiceInstance.create(guid: guid, plan_guid: plan_guid)
    end
  end

  def down
    services = Settings['services']
    plans = services.first['plans']
    raise 'Migration can only be run if the catalog has a single service with one plan' unless (1 == services.length && 1 == plans.length)

    drop_table :service_instances
  end
end
