class V2::CatalogsController < V2::BaseController
  def show

    services = Settings['services']
    service = services[0]
    plans = service['plans']
    plan = plans[0]

    render json: {
      services: [
        {
          id: service['id'],
          name: service['name'],
          description: service['description'],
          bindable: service['bindable'],
          tags: ['mysql', 'relational'],
          plans: [
            {
              id: plan['id'],
              name: plan['name'],
              description: plan['description']
            }
          ]
        }
      ]
    }
  end
end
