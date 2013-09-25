require 'spec_helper'

describe V2::ServiceInstancesController do
  let(:admin_user) { 'root' }
  let(:admin_password) { 'admin_password' }
  let(:database_host) { '10.10.1.1' }
  let(:database_port) { '3306' }

  before do
    authenticate
    allow(AppSettings).to receive(:database).and_return(
                              double(
                                  :admin_user => admin_user,
                                  :admin_password => admin_password,
                                  :host => database_host,
                                  :port => database_port)
                          )
  end

  describe '#update' do
    let(:instance_id) { 'INSTANCE-1' }
    let(:dbname) { DatabaseName.new(instance_id) }

    before do

      ActiveRecord::Base.connection.
          should_receive(:execute).
          with("CREATE DATABASE #{dbname.name};")
    end

    it 'sends back a dashboard url' do
      put :update, id: instance_id

      expect(response.status).to eq(201)
      instance = JSON.parse(response.body)

      expect(instance['dashboard_url']).to eq('http://fake.dashboard.url')
    end
  end

  describe '#destroy' do
    let(:instance_id) { 'INSTANCE-1' }
    let(:dbname) { DatabaseName.new(instance_id) }

    before do
      ActiveRecord::Base.connection.
          should_receive(:execute).
          with("DROP DATABASE #{dbname.name};")
    end

    it 'succeeds with 204' do
      delete :destroy, id: instance_id

      expect(response.status).to eq(204)
    end
  end
end
