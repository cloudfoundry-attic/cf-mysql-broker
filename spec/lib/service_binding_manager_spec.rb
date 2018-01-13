require 'spec_helper'

describe ServiceBindingManager do
  let(:binding_id) { '5c4ced82-1433-4ecb-bb82-a11dc07c089a' }

  let(:instance_guid) { "test-instance-#{SecureRandom.uuid}" }
  let(:instance) { ServiceInstance.new(guid: instance_guid, db_name: database) }
  let(:database) { ServiceInstanceManager.database_name_from_service_instance_guid(instance_guid) }

  before do
    allow(Database).to receive(:exists?).with(database).and_return(true)
  end

  describe '.create' do
    after do
      # this is so that we don't leave around extra users in the mysql.users table
      ServiceBinding.new(id: binding_id).destroy
    end

    it 'persists a ServiceBinding' do
      expect(ServiceBinding.exists?(id: binding_id, service_instance_guid: instance_guid)).to eq(false)
      described_class.create(id: binding_id, service_instance: instance)
      expect(ServiceBinding.exists?(id: binding_id, service_instance_guid: instance_guid)).to eq(true)
    end

    it 'returns the persisted ServiceBinding' do
      binding = described_class.create(id: binding_id, service_instance: instance)
      expect(binding).to be_present
      expect(binding.id).to eq(binding_id)
      expect(binding.service_instance).to eq(instance)
    end

    pending 'does not make the binding read-only' do
      binding = described_class.create(id: binding_id, service_instance: instance)
      expect(binding).to be_present
      expect(binding).not_to be_read_only
    end

    context 'when the read-only option is set' do
      pending 'grants read only access the given database' do
        binding = described_class.create(id: binding_id, service_instance: instance, read_only: true)
        expect(binding).to be_present
        expect(binding).not_to be_read_only
      end
    end
  end

  describe '.destroy' do
  end
end
