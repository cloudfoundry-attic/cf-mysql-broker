# These requires are needed because the quota enforcer
# is not running as a Rails application
require Rails.root.join('lib/settings')
require Rails.root.join('app/models/service')

class Catalog
  def self.has_plan?(plan_guid)
    find_plan_by_guid(plan_guid).present?
  end

  def self.plans
    services.map do |service|
      service.plans
    end.flatten
  end

  def self.quota_for_plan_guid(plan_guid)
    find_plan_by_guid(plan_guid).try(:max_storage_mb)
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
