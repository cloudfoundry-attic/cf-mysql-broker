class V2::ServiceInstancesController < V2::BaseController

  def create
    render status: 201, json: {id: params[:reference_id]}
  end
end
