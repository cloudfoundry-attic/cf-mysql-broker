require 'spec_helper'

describe V2::ServiceInstancesController do
  let(:instance_id) { '88f6fa22-c8b7-4cdc-be3a-dc09ea7734db' }

  before { authenticate }
  after { ServiceInstance.new(id: instance_id).destroy }

  # this is actually the create
  describe '#update' do
    let(:max_db_per_node) { 5 }
    let(:services) do
      [
        {
          'id' => 'foo',
          'name' => 'bar',
          'description' => 'desc',
          'bindable' => true,
          'max_db_per_node' => max_db_per_node
        }
      ]
    end

    let(:make_request) { put :update, id: instance_id }

    before do
      Settings.stub(:[]).with('services').and_return(services)
      Settings.stub(:[]).with('ssl_enabled').and_return(true)
    end

    it_behaves_like 'a controller action that requires basic auth'

    it_behaves_like 'a controller action that logs its request headers and body'

    context 'when ssl is set to false' do
      before do
        Settings.stub(:[]).with('ssl_enabled').and_return(false)
      end

      it 'returns a dashboard URL without https' do
        make_request

        instance = JSON.parse(response.body)
        expect(instance).to eq({ 'dashboard_url' => "http://pmysql.vcap.me/manage/instances/#{instance_id}" })
      end
    end

    context 'when below max_db_per_node quota' do
      before do
        ServiceInstance.stub(:get_number_of_existing_instances).and_return(3)
      end

      it 'creates the database and returns a 201' do
        expect(ServiceInstance.exists?(instance_id)).to eq(false)

        make_request

        expect(ServiceInstance.exists?(instance_id)).to eq(true)
        expect(response.status).to eq(201)
      end

      it 'returns the dashboard_url' do
        make_request

        instance = JSON.parse(response.body)
        expect(instance).to eq({ 'dashboard_url' => "https://pmysql.vcap.me/manage/instances/#{instance_id}" })
      end
    end

    context 'no max_db_per_node set' do
      let(:services) do
        [
          {
            'id' => 'foo',
            'name' => 'bar',
            'description' => 'desc',
            'bindable' => true
          }
        ]
      end

      it 'creates the database and returns a 201' do
        expect(ServiceInstance.exists?(instance_id)).to eq(false)

        make_request

        expect(ServiceInstance.exists?(instance_id)).to eq(true)
        expect(response.status).to eq(201)
      end

      it 'returns the dashboard_url' do
        make_request

        instance = JSON.parse(response.body)
        expect(instance).to eq({ 'dashboard_url' => "https://pmysql.vcap.me/manage/instances/#{instance_id}" })
      end
    end

    context 'when above max_db_per_node quota' do
      let(:extra_instance_id) { '88f6fa22-c8b7-4cdc-be3a-dc09ea7734da' }
      let(:make_request) { put :update, id: extra_instance_id }

      before do
        ServiceInstance.new(id: instance_id).save
        ServiceInstance.stub(:get_number_of_existing_instances).and_return(max_db_per_node)
      end

      after { ServiceInstance.new(id: instance_id).destroy }

      it 'does not create a database and gives you a 409' do
        expect(ServiceInstance.exists?(instance_id)).to eq(true)
        expect(ServiceInstance.exists?(extra_instance_id)).to eq(false)

        make_request

        expect(ServiceInstance.exists?(instance_id)).to eq(true)
        expect(ServiceInstance.exists?(extra_instance_id)).to eq(false)
        expect(response.status).to eq(507)
        response_json = JSON.parse(response.body)
        expect(response_json['description']).to eq('Service plan capacity has been reached')
      end
    end
  end

  describe '#destroy' do
    let(:make_request) { delete :destroy, id: instance_id }

    it_behaves_like 'a controller action that requires basic auth'

    it_behaves_like 'a controller action that logs its request headers and body'

    context 'when the database exists' do
      before { ServiceInstance.new(id: instance_id).save }

      it 'drops the database and returns a 200' do
        expect(ServiceInstance.exists?(instance_id)).to eq(true)

        make_request

        expect(ServiceInstance.exists?(instance_id)).to eq(false)
        expect(response.status).to eq(200)
        body = JSON.parse(response.body)
        expect(body).to eq({})
      end
    end

    context 'when the database does not exist' do
      it 'returns a 410' do
        make_request

        expect(response.status).to eq(410)
      end
    end
  end
end
