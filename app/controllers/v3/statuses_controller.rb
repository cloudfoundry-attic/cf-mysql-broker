class V3::StatusesController < V3::BaseController
  def show
    render json: ['OK']
  end
end
