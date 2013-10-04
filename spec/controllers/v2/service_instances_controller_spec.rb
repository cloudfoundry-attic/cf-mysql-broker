require 'spec_helper'

describe V2::ServiceInstancesController do
  let(:instance_id) { '88f6fa22-c8b7-4cdc-be3a-dc09ea7734db' }
  let(:database) { ServiceInstance.new(id: instance_id).database }

  before { authenticate }
  after { db.execute("DROP DATABASE IF EXISTS `#{database}`") }

  describe '#update' do
    it 'creates the database and returns a 201' do
      put :update, id: instance_id

      expect(db.select("SHOW DATABASES LIKE '#{database}'")).to have(1).record
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
      before { db.execute("CREATE DATABASE `#{database}`") }

      it 'drops the database and returns a 204' do
        delete :destroy, id: instance_id

        expect(db.select("SHOW DATABASES LIKE '#{database}'")).to have(0).records
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
