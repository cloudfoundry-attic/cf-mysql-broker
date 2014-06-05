class ServiceInstanceManager
  class ServiceInstanceNotFound < StandardError
  end

  DATABASE_PREFIX = 'cf_'.freeze

  def self.create(opts)
    guid = opts[:guid]
    plan_guid = opts[:plan_guid]

    if guid =~ /[^0-9,a-z,A-Z$-]+/
      raise 'Only GUIDs matching [0-9,a-z,A-Z$-]+ are allowed'
    end

    Database.create(database_name_from_service_instance_guid(guid))
    ServiceInstance.create(guid: guid, plan_guid: plan_guid)
  end

  def self.destroy(opts)
    guid = opts[:guid]
    instance = ServiceInstance.find_by_guid(guid)
    raise ServiceInstanceNotFound if instance.nil?
    instance.destroy
    Database.drop(database_name_from_service_instance_guid(guid))
  end

  private

  def self.database_name_from_service_instance_guid(guid)
    "#{DATABASE_PREFIX}#{guid.gsub('-', '_')}"
  end
end
