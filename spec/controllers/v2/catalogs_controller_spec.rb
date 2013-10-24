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
      expect(service.fetch('metadata')).to eq(
        {
          'listing' => {
            'imageUrl' => nil,
            'blurb' => 'MySQL service for application development and testing',
          }
        }
      )

      plans = service.fetch('plans')
      expect(plans).to have(1).plan

      plan = plans.first
      expect(plan.fetch('name')).to eq('free2')
      expect(plan.fetch('description')).to eq('Free Trial')
      expect(plan.fetch('id')).to eq('cf-mysql-plan-1')
      expect(plan.fetch('metadata')).to eq(
        {
          "cost"=> 0.0,
          "bullets" =>[
            { "content" => "Shared MySQL server" },
            { "content" => "100 MB storage" },
            { "content" => "40 concurrent connections" }
          ]
        }
      )
    end

    context 'when service metadata field is not set' do
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
      before do
        Settings.stub(:[]).with('services').and_return(services)
      end

      it 'should continue to present a valid catalog' do

        get :show
        expect(response.status).to eq(200)
        catalog = JSON.parse(response.body)

        services = catalog.fetch('services')
        expect(services).to have(1).service
        service = services.first
        expect(service['metadata']).to be_nil
      end
    end

    context 'when plan metadata field is not set' do
      let(:services) do
        [
          {
            'id' => 'foo',
            'name' => 'bar',
            'description' => 'desc',
            'bindable' => true,
            'metadata' => { 'foo' => 'bar' },
            'plans' => [
              'id' => 'plan-1',
              'name' => 'free',
              'description' => 'desc',
              'max_storage_db' => 5,
            ]
          }
        ]
      end
      before do
        Settings.stub(:[]).with('services').and_return(services)
      end

      it 'should continue to present a valid catalog' do
        get :show
        expect(response.status).to eq(200)
        catalog = JSON.parse(response.body)

        services = catalog.fetch('services')
        expect(services).to have(1).service
        plans = services.first.fetch('plans')
        expect(plans).to have(1).entry
        expect(plans.first['metadata']).to be_nil
      end
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
