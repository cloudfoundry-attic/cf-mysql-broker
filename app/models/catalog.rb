class Catalog
  def self.has_plan?(plan_guid)
    find_plan_by_guid(plan_guid).present?
  end

  def self.plans
    services.map do |service|
      service.plans
    end.flatten
  end

  def self.storage_quota_for_plan_guid(plan_guid)
    find_plan_by_guid(plan_guid).try(:max_storage_mb)
  end

  def self.connection_quota_for_plan_guid(plan_guid)
    find_plan_by_guid(plan_guid).try(:max_user_connections)
  end

  private

  def self.find_plan_by_guid(plan_guid)
    plans.detect do |plan|
      plan.id == plan_guid
    end
  end

  def self.services
    Settings['services'].map {|attrs| Service.build(attrs)}
  end
end
