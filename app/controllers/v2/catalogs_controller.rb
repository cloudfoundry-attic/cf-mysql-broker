class V2::CatalogsController < V2::BaseController
  def show
    render json: {
      services: services.map {|service| service.to_hash }
    }
  end

  private

  def services
    (Settings['services'] || []).map {|attrs| Service.build(attrs)}
  end
end
