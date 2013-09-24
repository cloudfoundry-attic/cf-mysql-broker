require 'spec_helper'

describe V2::ServiceBindingsController do
  before { authenticate }

  describe '#update' do
    let(:admin_user) { 'root' }
    let(:admin_password) { 'admin_password' }
    let(:singleton_database_name) { 'mydb' }
    let(:database_ip) { '10.10.1.1' }
    let(:database_port) { '3306' }

    let(:generated_username) { 'generated_user' }
    let(:generated_password) { 'generated_pw' }

    let(:creds) { double('user generator', username: generated_username, password: generated_password) }

    before do
      authenticate
      allow(AppSettings).to receive(:database).and_return(
                                double(
                                    :admin_user => admin_user,
                                    :admin_password => admin_password,
                                    :singleton_database => singleton_database_name,
                                    :ip => database_ip,
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
                                            'hostname' => database_ip,
                                            'name' => singleton_database_name,
                                            'username' => generated_username,
                                            'password' => generated_password,
                                            'port' => database_port,
                                            'jdbcUrl' => "jdbc:mysql://#{generated_username}:#{generated_password}@#{database_ip}:#{database_port}/#{singleton_database_name}",
                                            'uri' => "mysql://#{generated_username}:#{generated_password}@#{database_ip}:#{database_port}/#{singleton_database_name}?reconnect=true",
                                        )
    end
  end

  describe '#destroy' do
    it 'succeeds with 204' do
      delete :destroy, id: '42'

      expect(response.status).to eq(204)
    end
  end
end
