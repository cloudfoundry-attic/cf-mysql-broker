require 'spec_helper'

describe V2::CatalogsController do
  before { authenticate }

  describe '#show' do
    it 'returns the catalog of services' do
      get :show

      expect(response.status).to eq(200)
      catalog = JSON.parse(response.body)

      services = catalog.fetch('services')
      expect(services).to have(1).service

      service = services.first
      expect(service.fetch('name')).to eq('cf-mysql2')
      expect(service.fetch('description')).to eq('Cloud Foundry MySQL')
      expect(service.fetch('bindable')).to be_true
      expect(service.fetch('id')).to eq('cf-mysql-1')
      expect(service.fetch('tags')).to match_array(['mysql', 'relational'])

      plans = service.fetch('plans')
      expect(plans).to have(1).plan

      plan = plans.first
      expect(plan.fetch('name')).to eq('free2')
      expect(plan.fetch('description')).to eq('Free Trial')
      expect(plan.fetch('id')).to eq('cf-mysql-plan-1')
    end

    #context 'when settings are misconfigured' do
    #  it "expects a 'services' node" do
    #    Settings.stub(:[]).with('services').and_return(nil)
    #    get :show
    #    expect(response.status).to eq(500)
    #    error = JSON.parse(response.body)
    #
    #    expect(error.fetch('description')).to match(/Missing configuration 'services'/)
    #  end
    #end
  end
end
