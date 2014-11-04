class V2::ServiceInstancesController < V2::BaseController

  # This is actually the create
  def update
    plan_guid = params.fetch(:plan_id)

    unless Catalog.has_plan?(plan_guid)
      return render status: 422, json: {'description' => "Cannot create a service instance. Plan #{plan_guid} was not found in the catalog."}
    end

    plan_max_storage_mb = Catalog.storage_quota_for_plan_guid(plan_guid)

    if ServiceCapacity.can_allocate?(plan_max_storage_mb)
      instance_guid = params.fetch(:id)
      instance = ServiceInstanceManager.create(guid: instance_guid, plan_guid: plan_guid)

      render status: 201, json: { dashboard_url: build_dashboard_url(instance) }
    else
      render status: 507, json: {'description' => 'Service capacity has been reached'}
    end
  end

  def set_plan
    instance_guid = params.fetch(:id)
    plan_guid = params.fetch(:plan_id)

    begin
      ServiceInstanceManager.set_plan(guid: instance_guid, plan_guid: plan_guid)
      status = 200
      body = {}
    rescue ServiceInstanceManager::ServiceInstanceNotFound
      status = 404
      body = { description: 'Service instance not found' }
    rescue ServiceInstanceManager::ServicePlanNotFound
      status = 400
      body = { description: 'Service plan not found' }
    rescue ServiceInstanceManager::InvalidServicePlanUpdate => e
      status = 422
      body = { description: e.message }
    end

    render status: status, json: body
  end

  def destroy
    instance_guid = params.fetch(:id)
    begin
      ServiceInstanceManager.destroy(guid: instance_guid)
      status = 200
    rescue ServiceInstanceManager::ServiceInstanceNotFound
      status = 410
    end

    render status: status, json: {}
  end

  private

  def build_dashboard_url(instance)
    domain = Settings.external_host
    path   = manage_instance_path(instance.guid)

    "#{scheme}://#{domain}#{path}"
  end

  def scheme
    Settings['ssl_enabled'] == false ? 'http': 'https'
  end
end
