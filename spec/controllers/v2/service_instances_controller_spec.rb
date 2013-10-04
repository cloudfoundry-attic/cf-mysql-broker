require 'spec_helper'

describe V2::ServiceInstancesController do
  let(:instance_id) { '88f6fa22-c8b7-4cdc-be3a-dc09ea7734db' }
  let(:database) { ServiceInstance.new(id: instance_id).database }

  before { authenticate }
  after { ServiceInstance.new(id: instance_id).destroy }

  describe '#update' do
    it 'creates the database and returns a 201' do
      expect(ServiceInstance.exists?(instance_id)).to eq(false)

      put :update, id: instance_id

      expect(ServiceInstance.exists?(instance_id)).to eq(true)
      expect(response.status).to eq(201)
    end

    it 'sends back a dashboard url' do
      put :update, id: instance_id

      instance = JSON.parse(response.body)
      expect(instance['dashboard_url']).to eq('http://fake.dashboard.url')
    end
  end

  describe '#destroy' do
    context 'when the database exists' do
      before { ServiceInstance.new(id: instance_id).save }

      it 'drops the database and returns a 204' do
        expect(ServiceInstance.exists?(instance_id)).to eq(true)

        delete :destroy, id: instance_id

        expect(ServiceInstance.exists?(instance_id)).to eq(false)
        expect(response.status).to eq(204)
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
