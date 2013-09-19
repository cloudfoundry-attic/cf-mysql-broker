class V2::ServiceInstancesController < V2::BaseController

  # This is actually the create
  def update
    render status: 201, json: { dashboard_url: 'http://fake.dashboard.url' }
  end

  def destroy
    render status: 204, json: {}
  end
end
