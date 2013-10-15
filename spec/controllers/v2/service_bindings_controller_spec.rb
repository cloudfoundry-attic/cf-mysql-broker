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
    let(:generated_password) { 'generatedpw' }

    before { SecureRandom.stub(:base64).and_return(generated_password, 'notthepassword') }
    after { ServiceBinding.new(id: binding_id, service_instance: instance).destroy }

    it 'grants permission to access the given database' do
      expect(ServiceBinding.exists?(id: binding_id, service_instance_id: instance_id)).to eq(false)

      put :update, id: binding_id, service_instance_id: instance_id

      expect(ServiceBinding.exists?(id: binding_id, service_instance_id: instance_id)).to eq(true)
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
      after { binding.destroy }

      it 'destroys the user' do
        expect(ServiceBinding.exists?(id: binding.id, service_instance_id: instance.id)).to eq(true)

        delete :destroy, id: binding.id

        expect(ServiceBinding.exists?(id: binding.id, service_instance_id: instance.id)).to eq(false)
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
