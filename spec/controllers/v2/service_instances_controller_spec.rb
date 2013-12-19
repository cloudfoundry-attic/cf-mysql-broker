require 'spec_helper'

describe V2::ServiceInstancesController do
  let(:instance_id) { '88f6fa22-c8b7-4cdc-be3a-dc09ea7734db' }
  let(:database) { ServiceInstance.new(id: instance_id).database }

  before { authenticate }
  after { ServiceInstance.new(id: instance_id).destroy }

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

    before do
      Settings.stub(:[]).with('services').and_return(services)
    end

    context 'when below max_db_per_node quota' do

      before do
        ServiceInstance.stub(:get_number_of_existing_instances).and_return(3)
      end

      it 'creates the database and returns a 201' do
        expect(ServiceInstance.exists?(instance_id)).to eq(false)

        put :update, id: instance_id

        expect(ServiceInstance.exists?(instance_id)).to eq(true)
        expect(response.status).to eq(201)
      end

      it 'sends back empty json' do
        put :update, id: instance_id

        instance = JSON.parse(response.body)
        expect(instance).to eq({})
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

        put :update, id: instance_id

        expect(ServiceInstance.exists?(instance_id)).to eq(true)
        expect(response.status).to eq(201)
      end
    end

    context 'when above max_db_per_node quota' do
      let(:extra_instance_id) { '88f6fa22-c8b7-4cdc-be3a-dc09ea7734da' }

      before do
        ServiceInstance.new(id: instance_id).save
        ServiceInstance.stub(:get_number_of_existing_instances).and_return(max_db_per_node)
      end

      after { ServiceInstance.new(id: instance_id).destroy }

      it 'does not create a database and gives you a 409' do
        expect(ServiceInstance.exists?(instance_id)).to eq(true)
        expect(ServiceInstance.exists?(extra_instance_id)).to eq(false)

        put :update, id: extra_instance_id

        expect(ServiceInstance.exists?(instance_id)).to eq(true)
        expect(ServiceInstance.exists?(extra_instance_id)).to eq(false)
        expect(response.status).to eq(507)
        response_json = JSON.parse(response.body)
        expect(response_json['description']).to eq('Service plan capacity has been reached')
      end
    end
  end

  describe '#destroy' do
    context 'when the database exists' do
      before { ServiceInstance.new(id: instance_id).save }

      it 'drops the database and returns a 200' do
        expect(ServiceInstance.exists?(instance_id)).to eq(true)

        delete :destroy, id: instance_id

        expect(ServiceInstance.exists?(instance_id)).to eq(false)
        expect(response.status).to eq(200)
        body = JSON.parse(response.body)
        expect(body).to eq({})
      end
    end

    context 'when the database does not exist' do
      it 'returns a 410' do
        delete :destroy, id: instance_id

        expect(response.status).to eq(410)
      end
    end
  end
end
