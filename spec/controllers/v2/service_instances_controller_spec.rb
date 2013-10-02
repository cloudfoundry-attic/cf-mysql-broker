require 'spec_helper'

describe V2::ServiceInstancesController do
  let(:db_settings) { Rails.configuration.database_configuration[Rails.env] }
  let(:admin_user) { db_settings.fetch('username') }
  let(:admin_password) { db_settings.fetch('password') }
  let(:database_host) { db_settings.fetch('host') }
  let(:database_port) { db_settings.fetch('port') }

  let(:instance_id) { 'INSTANCE-1' }
  let(:dbname) { DatabaseName.new(instance_id) }

  before { authenticate }
  after { db.execute("DROP DATABASE IF EXISTS #{dbname.name}") }

  describe '#update' do
    it 'creates the database and returns a 201' do
      put :update, id: instance_id

      expect(db.select("SHOW DATABASES LIKE '#{dbname.name}'")).to have(1).record
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
      before { db.execute("CREATE DATABASE #{dbname.name}") }

      it 'drops the database and returns a 204' do
        delete :destroy, id: instance_id

        expect(db.select("SHOW DATABASES LIKE '#{dbname.name}'")).to have(0).records
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
