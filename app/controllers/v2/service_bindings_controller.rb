class V2::ServiceBindingsController < V2::BaseController
  def update
    instance = ServiceInstance.find(params.fetch(:service_instance_id))
    binding = ServiceBinding.new(id: params.fetch(:id), service_instance: instance)
    binding.save

    respond_with binding
  end

  def destroy
    if binding = ServiceBinding.find_by_id(params.fetch(:id))
      binding.destroy
    end

    respond_with binding
  end
end
