class V2::ServiceBindingsController < V2::BaseController
  def update
    instance = ServiceInstance.find(params.fetch(:service_instance_id))
    binding = ServiceBinding.new(id: params.fetch(:id), service_instance: instance)
    binding.save

    render status: 201, json: binding
  end

  def destroy
    if binding = ServiceBinding.find_by_id(params.fetch(:id))
      binding.destroy
      status = 200
    else
      status = 410
    end

    render status: status, json: {}
  end
end
