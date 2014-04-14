class V2::ServiceInstancesController < V2::BaseController
  # This is actually the create
  def update
    quota = Settings['services'][0]['max_db_per_node']
    existing_instances = ServiceInstance.get_number_of_existing_instances

    if !quota or existing_instances < quota
      instance = ServiceInstance.new(id: params.fetch(:id))
      instance.save

      render status: 201, json: { dashboard_url: build_dashboard_url(instance) }
    else
      render status: 507, json: {'description' => 'Service plan capacity has been reached'}
    end

  end

  def destroy
    if instance = ServiceInstance.find_by_id(params.fetch(:id))
      instance.destroy
      status = 200
    else
      status = 410
    end

    render status: status, json: {}
  end

  private

  def build_dashboard_url(instance)
    domain = Settings.external_host
    path   = manage_instance_path(instance.id)

    "#{scheme}://#{domain}#{path}"
  end

  def scheme
    Settings['ssl_enabled'] == false ? 'http': 'https'
  end
end
