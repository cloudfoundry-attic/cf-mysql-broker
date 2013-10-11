class V2::CatalogsController < V2::BaseController
  def show
    services = Settings['services']

    render json: {
      services: services_list(services)
    }
  end

  def services_list(services)
    services ||= []
    services.map do |service|
      {
        id: service['id'],
        name: service['name'],
        description: service['description'],
        bindable: service['bindable'],
        tags: ['mysql', 'relational'],
        plans: plans_list(service['plans'])
      }
    end
  end

  def plans_list(plans)
    plans ||= []
    plans.map do |plan|
      {
        id: plan['id'],
        name: plan['name'],
        description: plan['description']
      }
    end
  end
end
