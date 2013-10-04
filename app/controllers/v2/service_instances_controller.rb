class V2::ServiceInstancesController < V2::BaseController
  # This is actually the create
  def update
    instance = ServiceInstance.new(id: params.fetch(:id))
    instance.save

    respond_with instance
  end

  def destroy
    if instance = ServiceInstance.find_by_id(params.fetch(:id))
      instance.destroy
    end

    respond_with instance
  end
end
