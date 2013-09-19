class V2::ServiceBindingsController < V2::BaseController

  def create
    render status: 201, json: { credentials: '{ "foo": "bar" }' }
  end
end
