class V2::ServiceInstancesController < V2::BaseController
  # This is actually the create
  def update
    instance = ServiceInstance.new(id: params.fetch(:id))
    instance.save

    render status: 201, json: instance
  end

  def destroy
    if instance = ServiceInstance.find_by_id(params.fetch(:id))
      instance.destroy
      status = 204
    else
      status = 410
    end

    render status: status, json: {}
  end
end
