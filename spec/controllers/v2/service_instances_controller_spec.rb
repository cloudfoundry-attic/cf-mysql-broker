require 'spec_helper'

describe V2::ServiceInstancesController do
  let(:instance_id) { '88f6fa22-c8b7-4cdc-be3a-dc09ea7734db' }

  before { authenticate }

  # this is actually the create
  describe '#update' do
    let(:max_db_per_node) { 5 }
    let(:max_storage_mb) { 5 }
    let(:services) do
      [
          {
              'id' => 'foo',
              'name' => 'bar',
              'description' => 'desc',
              'bindable' => true,
              'plans' => [
                  {
                      'id' => 'plan_id',
                      'name' => 'plan_name',
                      'description' => 'desc',
                      'max_storage_mb' => 5,
                  }
              ]
          }.merge(extra_service_attributes)
      ]
    end
    let(:extra_service_attributes) { {
        'max_db_per_node' => max_db_per_node
    } }
    let(:plan_id) { 'plan_id' }
    let(:make_request) do
      put :update, {
          id: instance_id,
          plan_id: plan_id
      }
    end

    before do
      Settings.stub(:[]).with('services').and_return(services)
      Settings.stub(:[]).with('ssl_enabled').and_return(true)
    end

    it_behaves_like 'a controller action that requires basic auth'

    it_behaves_like 'a controller action that logs its request and response headers and body'

    context 'when ssl is set to false' do
      before do
        Settings.stub(:[]).with('ssl_enabled').and_return(false)
      end

      it 'returns a dashboard URL without https' do
        make_request

        instance = JSON.parse(response.body)
        expect(instance).to eq({'dashboard_url' => "http://pmysql.vcap.me/manage/instances/#{instance_id}"})
      end
    end

    context 'when the provided plan_id is not present in the catalog' do
      let(:plan_id) { "does-not-exist-in-catalog" }

      it 'does not attempt to create a service instance' do
        expect(ServiceInstanceManager).not_to receive(:create)
        make_request
      end

      it 'returns a 422 status code with a descriptive error message' do
        make_request

        expect(response.status).to eq(422)
        body = JSON.parse(response.body)
        expect(body['description']).to match /Cannot create a service instance. Plan does-not-exist-in-catalog was not found in the catalog./
      end
    end

    context 'when below max_db_per_node quota' do
      before do
        (max_db_per_node - 1).times do |index|
          ServiceInstance.create(guid: "instance-guid-#{index}", plan_guid: plan_id)
        end
      end

      it 'returns a 201' do
        make_request
        expect(response.status).to eq(201)
      end

      it 'tells the ServiceInstanceManager to create an instance with the correct attributes' do
        expect(ServiceInstanceManager).to receive(:create).with({
          guid: instance_id,
          plan_guid: plan_id
        }).and_return(ServiceInstance.new(guid: instance_id, plan_guid: plan_id, max_storage_mb: max_storage_mb))

        make_request
      end

      it 'returns the dashboard_url' do
        make_request

        instance = JSON.parse(response.body)
        expect(instance).to eq({'dashboard_url' => "https://pmysql.vcap.me/manage/instances/#{instance_id}"})
      end
    end

    context 'no max_db_per_node set' do
      let(:extra_service_attributes) { {} }

      before do
        ServiceInstance.create(guid: "instance-guid-0", plan_guid: plan_id)
      end

      it 'returns a 201' do
        make_request
        expect(response.status).to eq(201)
      end

      it 'tells the ServiceInstanceManager to create an instance with the correct attributes' do
        expect(ServiceInstanceManager).to receive(:create).with({
            guid: instance_id,
            plan_guid: plan_id
        }).and_return(ServiceInstance.new(guid: instance_id, plan_guid: plan_id, max_storage_mb: max_storage_mb))

        make_request
      end

      it 'returns the dashboard_url' do
        make_request

        instance = JSON.parse(response.body)
        expect(instance).to eq({'dashboard_url' => "https://pmysql.vcap.me/manage/instances/#{instance_id}"})
      end
    end

    context 'when above max_db_per_node quota' do
      before do
        max_db_per_node.times do |index|
          ServiceInstance.create(guid: "instance-guid-#{index}", plan_guid: plan_id)
        end
      end

      it 'returns a 507' do
        make_request

        expect(response.status).to eq(507)
        response_json = JSON.parse(response.body)
        expect(response_json['description']).to eq('Service plan capacity has been reached')
      end

      it 'does not attempt to create a service instance' do
        expect(ServiceInstanceManager).not_to receive(:create)
        make_request
      end
    end
  end

  describe '#destroy' do
    let(:make_request) { delete :destroy, id: instance_id }

    it_behaves_like 'a controller action that requires basic auth'

    it_behaves_like 'a controller action that logs its request and response headers and body'

    context 'when the service instance exists' do
      before do
        ServiceInstance.create(guid: instance_id, plan_guid: 'some-plan-guid')
      end

      it 'returns a 200' do
        make_request

        expect(response.status).to eq(200)
        body = JSON.parse(response.body)
        expect(body).to eq({})
      end

      it 'tells the service instance manager to destroy the instance' do
        expect(ServiceInstanceManager).to receive(:destroy).with({
            guid: instance_id
        })

        make_request
      end
    end

    context 'when the service instance does not exist' do
      it 'returns a 410' do
        expect(ServiceInstanceManager).to receive(:destroy).with({
          guid: instance_id
        }).and_raise(ServiceInstanceManager::ServiceInstanceNotFound)

        make_request

        expect(response.status).to eq(410)
      end
    end
  end
end
