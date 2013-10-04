require 'spec_helper'

describe V2::ServiceBindingsController do
  let(:db_settings) { Rails.configuration.database_configuration[Rails.env] }
  let(:admin_user) { db_settings.fetch('username') }
  let(:admin_password) { db_settings.fetch('password') }
  let(:database_host) { db_settings.fetch('host') }
  let(:database_port) { db_settings.fetch('port') }

  let(:instance_id) { 'instance-1' }
  let(:instance) { ServiceInstance.new(id: instance_id) }

  before do
    authenticate
    instance.save
  end

  after { instance.destroy }

  describe '#update' do
    let(:binding_id) { '123' }
    let(:generated_dbname) { ServiceInstance.new(id: instance_id).database }

    let(:generated_username) { ServiceBinding.new(id: binding_id).username }
    let(:generated_password) { 'generated_pw' }

    before { SecureRandom.stub(:hex).with(8).and_return(generated_password, 'not-the-password') }
    after { db.execute("DROP USER '#{generated_username}'@'%'") }

    it 'grants permission to access the given database' do
      put :update, id: binding_id, service_instance_id: instance_id

      expect(db.select_values("SHOW GRANTS FOR #{generated_username}")).to include("GRANT ALL PRIVILEGES ON `#{generated_dbname}`.* TO '#{generated_username}'@'%'")
    end

    it 'responds with generated credentials' do
      put :update, id: binding_id, service_instance_id: instance_id

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
      put :update, id: binding_id, service_instance_id: instance_id

      expect(response.status).to eq(201)
    end
  end

  describe '#destroy' do
    let(:binding_id) { 'BINDING-1' }
    let(:binding) { ServiceBinding.new(id: binding_id, service_instance: instance) }
    let(:username) { binding.username }

    context 'when the user exists' do
      before { binding.save }

      after do
        begin
          db.execute("DROP USER #{username}")
        rescue ActiveRecord::StatementInvalid => e
          raise unless e.message =~ /DROP USER failed/
        end
      end

      it 'destroys the user' do
        delete :destroy, id: binding.id

        expect {
          db.select("SHOW GRANTS FOR '#{username}'@'%'")
        }.to raise_error(ActiveRecord::StatementInvalid, /no such grant defined/)
        expect {
          db.select("SHOW GRANTS FOR '#{username}'@'localhost'")
        }.to raise_error(ActiveRecord::StatementInvalid, /no such grant defined/)
      end

      it 'returns a 204' do
        delete :destroy, id: binding.id

        expect(response.status).to eq(204)
      end
    end

    context 'when the user does not exist' do
      it 'returns a 410' do
        delete :destroy, id: binding.id

        expect(response.status).to eq(410)
      end
    end
  end
end
