require 'spec_helper'

describe V2::ServiceInstancesController do
  let(:instance_id) { '88f6fa22-c8b7-4cdc-be3a-dc09ea7734db' }

  before { authenticate }

  # this is actually the create
  describe '#update' do
    let(:max_storage_mb) { 5 }
    let(:db_name) { ServiceInstanceManager.database_name_from_service_instance_guid(instance_id) }
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
                  },
                {
                  'id' => 'new-plan-guid',
                  'name' => 'plan_name',
                  'description' => 'desc',
                  'max_storage_mb' => 12,
                }
              ]
          }
      ]
    end
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
      ServiceCapacity.stub(:can_allocate?).with(max_storage_mb).and_return(true)
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

    context 'when creating additional instances is allowed' do
      before do
        ServiceCapacity.stub(:can_allocate?).with(max_storage_mb) { true }
      end

      it 'returns a 201' do
        make_request
        expect(response.status).to eq(201)
      end

      it 'tells the ServiceInstanceManager to create an instance with the correct attributes' do
        expect(ServiceInstanceManager).to receive(:create).with({
          guid: instance_id,
          plan_guid: plan_id
        }).and_return(ServiceInstance.new(guid: instance_id, plan_guid: plan_id, max_storage_mb: max_storage_mb, db_name: db_name))

        make_request
      end

      it 'returns the dashboard_url' do
        make_request

        instance = JSON.parse(response.body)
        expect(instance).to eq({'dashboard_url' => "https://pmysql.vcap.me/manage/instances/#{instance_id}"})
      end
    end

    context 'when creating additional instances is not allowed' do
      before do
        ServiceCapacity.stub(:can_allocate?).with(max_storage_mb) { false }
      end

      it 'returns a 507' do
        make_request

        expect(response.status).to eq(507)
        response_json = JSON.parse(response.body)
        expect(response_json['description']).to eq('Service capacity has been reached')
      end

      it 'does not attempt to create a service instance' do
        expect(ServiceInstanceManager).not_to receive(:create)
        make_request
      end
    end
  end

  describe '#set_plan' do
    let(:plan_id) { 'new-plan-guid' }
    let(:make_request) { patch :set_plan, id: instance_id, plan_id: plan_id }

    before do
      ServiceInstanceManager.stub(:set_plan)

      request_body = {plan_id: 'new-plan-guid'}.to_json
      request.env['RAW_POST_DATA'] = request_body
    end

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

      it 'tells the service instance manager to change the plan of the instance' do
        expect(ServiceInstanceManager).to receive(:set_plan).with({
              guid: instance_id,
            plan_guid: 'new-plan-guid'
        })

        make_request
      end
    end

    context 'when the service instance does not exist' do
      before do
        allow(ServiceInstanceManager).to receive(:set_plan).with({
          guid: instance_id,
          plan_guid: 'new-plan-guid'
        }).and_raise(ServiceInstanceManager::ServiceInstanceNotFound)
      end

      it 'returns a 404' do
        make_request

        expect(response.status).to eq(404)
        expect(response.body).to eq '{"description":"Service instance not found"}'
      end
    end

    context 'when the service plan does not exist' do
      before do
        allow(ServiceInstanceManager).to receive(:set_plan).with({
          guid: instance_id,
          plan_guid: 'new-plan-guid'
        }).and_raise(ServiceInstanceManager::ServicePlanNotFound)
      end

      it 'returns a 400' do
        make_request

        expect(response.status).to eq(400)
        expect(response.body).to eq '{"description":"Service plan not found"}'
      end
    end

    context 'when the service plan cannot be updated' do
      before do
        allow(ServiceInstanceManager).to receive(:set_plan).and_raise(ServiceInstanceManager::InvalidServicePlanUpdate.new('cannot downgrade'))
      end

      it 'returns a 422 and forwards the error message' do
        make_request

        expect(response.status).to eq 422
        expect(response.body).to eq '{"description":"cannot downgrade"}'
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
