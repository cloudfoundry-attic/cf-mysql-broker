class V2::CatalogsController < V2::BaseController
  def show
    render json: {
      services: [
        {
          id: 'cf-mysql-1',
          name: 'cf-mysql',
          description: 'Cloud Foundry MySQL',
          bindable: true,
          plans: [
            {
              id: 'cf-mysql-plan-1',
              name: 'free',
              description: 'Free Trial'
            }
          ]
        }
      ]
    }
  end
end
