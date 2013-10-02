require 'spec_helper'

describe V2::ServiceBindingsController do
  let(:db_settings) { Rails.configuration.database_configuration[Rails.env] }
  let(:admin_user) { db_settings.fetch('username') }
  let(:admin_password) { db_settings.fetch('password') }
  let(:database_host) { db_settings.fetch('host') }
  let(:database_port) { db_settings.fetch('port') }

  before do
    authenticate
  end

  describe '#update' do
    let(:instance_id) { 'INSTANCE-1' }
    let(:generated_dbname) { DatabaseName.new(instance_id).name }

    let(:generated_username) { 'generated_user' }
    let(:generated_password) { 'generated_pw' }

    let(:creds) { double('UserCreds', username: generated_username, password: generated_password) }

    before { UserCreds.stub(:new).with('123').and_return(creds) }
    after { db.execute("DROP USER '#{generated_username}'@'%'") }

    it 'grants permission to access the given database' do
      put :update, id: 123, service_instance_id: instance_id

      expect(db.select_values("SHOW GRANTS FOR #{generated_username}")).to include("GRANT ALL PRIVILEGES ON `#{generated_dbname}`.* TO '#{generated_username}'@'%'")
    end

    it 'responds with generated credentials' do
      put :update, id: 123, service_instance_id: instance_id

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

    it 'returns a 201' do
      put :update, id: 123, service_instance_id: instance_id

      expect(response.status).to eq(201)
    end
  end

  describe '#destroy' do
    let(:binding_id) { 'BINDING-1' }
    let(:username) { UserCreds.new(binding_id).username }

    context 'when the user exists' do
      before { db.execute("CREATE USER '#{username}'") }

      it 'destroys the user' do
        delete :destroy, id: binding_id

        expect {
          db.select("SHOW GRANTS FOR '#{username}'@'%'")
        }.to raise_error(ActiveRecord::StatementInvalid, /no such grant defined/)
        expect {
          db.select("SHOW GRANTS FOR '#{username}'@'localhost'")
        }.to raise_error(ActiveRecord::StatementInvalid, /no such grant defined/)
      end

      it 'returns a 204' do
        delete :destroy, id: binding_id

        expect(response.status).to eq(204)
      end
    end

    context 'when the user does not exist' do
      it 'returns a 410' do
        delete :destroy, id: binding_id

        expect(response.status).to eq(410)
      end
    end
  end
end
