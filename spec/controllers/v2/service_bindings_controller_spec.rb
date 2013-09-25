require 'spec_helper'

describe V2::ServiceBindingsController do
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
    let(:generated_dbname) { DatabaseName.new(instance_id).name }

    let(:generated_username) { 'generated_user' }
    let(:generated_password) { 'generated_pw' }

    let(:creds) { double('UserCreds', username: generated_username, password: generated_password) }

    before do
      UserCreds.stub(:new).with('123').and_return(creds)

      ActiveRecord::Base.connection.
          should_receive(:execute).
          with("CREATE USER '#{generated_username}' IDENTIFIED BY '#{generated_password}';")

      ActiveRecord::Base.connection.
          should_receive(:execute).
          with("GRANT ALL PRIVILEGES ON #{generated_dbname}.* TO '#{generated_username}';")

      ActiveRecord::Base.connection.
          should_receive(:execute).
          with("FLUSH PRIVILEGES;")
    end

    it 'responds with generated credentials' do
      put :update, id: 123, service_instance_id: instance_id

      expect(response.status).to eq(201)
      binding = JSON.parse(response.body)

      expect(binding['credentials']).to eq(
                                            'hostname' => database_host,
                                            'name' => generated_dbname,
                                            'username' => generated_username,
                                            'password' => generated_password,
                                            'port' => database_port,
                                            'jdbcUrl' => "jdbc:mysql://#{generated_username}:#{generated_password}@#{database_host}:#{database_port}/#{generated_dbname}",
                                            'uri' => "mysql://#{generated_username}:#{generated_password}@#{database_host}:#{database_port}/#{generated_dbname}?reconnect=true",
                                        )
    end
  end

  describe '#destroy' do
    let(:binding_id) { 'BINDING-1' }
    let(:username) { UserCreds.new(binding_id).username }

    before do
      ActiveRecord::Base.connection.
          should_receive(:execute).
          with("DROP USER '#{username}';")

      ActiveRecord::Base.connection.
          should_receive(:execute).
          with("FLUSH PRIVILEGES;")
    end

    it 'succeeds with 204' do
      delete :destroy, id: binding_id

      expect(response.status).to eq(204)
    end
  end
end
