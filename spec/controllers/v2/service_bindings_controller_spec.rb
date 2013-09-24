require 'spec_helper'

describe V2::ServiceBindingsController do
  let(:admin_user) { 'root' }
  let(:admin_password) { 'admin_password' }
  let(:singleton_database_name) { 'mydb' }
  let(:database_host) { '10.10.1.1' }
  let(:database_port) { '3306' }

  before do
    authenticate
    allow(AppSettings).to receive(:database).and_return(
                            double(
                                :admin_user => admin_user,
                                :admin_password => admin_password,
                                :singleton_database => singleton_database_name,
                                :host => database_host,
                                :port => database_port)
                          )
  end

  describe '#update' do
    let(:generated_username) { 'generated_user' }
    let(:generated_password) { 'generated_pw' }

    let(:creds) { double('user generator', username: generated_username, password: generated_password) }

    before do
      allow(AppSettings).to receive(:database).and_return(
                                double(
                                    :admin_user => admin_user,
                                    :admin_password => admin_password,
                                    :singleton_database => singleton_database_name,
                                    :host => database_host,
                                    :port => database_port
                                )
                            )

      UserCreds.stub(:new).with('123').and_return(creds)

      ActiveRecord::Base.connection.
          should_receive(:execute).
          with("CREATE USER '#{generated_username}' IDENTIFIED BY '#{generated_password}';")

      ActiveRecord::Base.connection.
          should_receive(:execute).
          with("GRANT ALL PRIVILEGES ON *.* TO '#{generated_username}';")

      ActiveRecord::Base.connection.
          should_receive(:execute).
          with("FLUSH PRIVILEGES;")
    end

    it 'responds with generated credentials' do
      put :update, id: 123

      expect(response.status).to eq(201)
      binding = JSON.parse(response.body)

      expect(binding['credentials']).to eq(
                                            'hostname' => database_host,
                                            'name' => singleton_database_name,
                                            'username' => generated_username,
                                            'password' => generated_password,
                                            'port' => database_port,
                                            'jdbcUrl' => "jdbc:mysql://#{generated_username}:#{generated_password}@#{database_host}:#{database_port}/#{singleton_database_name}",
                                            'uri' => "mysql://#{generated_username}:#{generated_password}@#{database_host}:#{database_port}/#{singleton_database_name}?reconnect=true",
                                        )
    end
  end

  describe '#destroy' do
    let(:binding_guid) { 'BINDING-1' }
    let(:username) { UserCreds.new(binding_guid).username }

    before do
      ActiveRecord::Base.connection.
          should_receive(:execute).
          with("DROP USER '#{username}';")

      ActiveRecord::Base.connection.
          should_receive(:execute).
          with("FLUSH PRIVILEGES;")
    end

    it 'succeeds with 204' do
      delete :destroy, id: binding_guid

      expect(response.status).to eq(204)
    end
  end
end
