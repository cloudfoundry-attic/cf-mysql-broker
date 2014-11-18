class V2::ServiceBindingsController < V2::BaseController
  def update
    instance = ServiceInstance.find_by_guid(params.fetch(:service_instance_id))
    if instance.nil?
      render status: 404, json: {}
      return
    end
    binding = ServiceBinding.new(id: params.fetch(:id), service_instance: instance)
    binding.save

    render status: 201, json: binding
  end

  def destroy
    binding = ServiceBinding.find_by_id(params.fetch(:id))
    if binding
      binding.destroy
      status = 200
    else
      status = 410
    end

    render status: status, json: {}
  end
end
