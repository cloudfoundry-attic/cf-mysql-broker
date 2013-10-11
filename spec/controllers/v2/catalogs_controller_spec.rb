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

    context 'with invalid catalog data' do
      let(:services) { nil }
      before do
        Settings.stub(:[]).with('services').and_return(services)
      end

      context 'when there are no services' do
        it 'produces an empty catalog' do
          get :show
          expect(response.status).to eq(200)
          catalog = JSON.parse(response.body)

          services = catalog.fetch('services')
          expect(services).to have(0).service
        end
      end

      context 'when there are no plans' do
        let(:services) do
          [
            {
              'id' => 'foo',
              'name' => 'bar',
              'description' => 'desc',
              'bindable' => true,
            }
          ]
        end

        it 'produces a catalog with no plans' do
          get :show
          expect(response.status).to eq(200)
          catalog = JSON.parse(response.body)

          services = catalog.fetch('services')
          expect(services).to have(1).service
          expect(services.first.fetch('plans')).to eq([])
        end
      end
    end
  end
end
