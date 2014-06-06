require 'spec_helper'

describe ServiceInstanceManager do
  let(:instance_id) { '88f6fa22-c8b7-4cdc-be3a-dc09ea7734db' }
  let(:database_name) { 'cf_88f6fa22_c8b7_4cdc_be3a_dc09ea7734db' }
  let(:plan_id) { '8888-ffff' }

  describe '.create' do
    after {
      Database.drop(database_name)
    }

    it 'saves a ServiceInstance in the broker database' do
      expect { described_class.create(guid: instance_id, plan_guid: plan_id) }.
          to change(ServiceInstance, :count).from(0).to(1)
      expect(ServiceInstance.last.guid).to eq(instance_id)
      expect(ServiceInstance.last.plan_guid).to eq(plan_id)
    end

    it 'creates a new MySQL database' do
      described_class.create(guid: instance_id, plan_guid: plan_id)
      expect(Database.exists?(database_name)).to eq true
    end

    context 'when creating the MySQL database fails' do
      before do
        expect(Database).to receive(:create).and_raise(ActiveRecord::ActiveRecordError)
      end

      it 'does not save a ServiceInstance in the broker database' do
        expect {
          begin
            described_class.create(guid: instance_id, plan_guid: plan_id)
          rescue ActiveRecord::ActiveRecordError
          end
        }.not_to change(ServiceInstance, :count)
      end
    end

    context 'when the instance guid is of the wrong format' do
      it 'raises an error' do
        expect {
          described_class.create(guid: 'Very$%$%#$BAD--__,,guid', plan_guid: plan_id)
        }.to raise_error(RuntimeError, 'Only GUIDs matching [0-9,a-z,A-Z$-]+ are allowed')
      end

      it 'does not save a ServiceInstance in the broker database' do
        expect {
          begin
            described_class.create(guid: 'Very$%$%#$BAD--__,,guid', plan_guid: plan_id)
          rescue RuntimeError
          end
        }.not_to change(ServiceInstance, :count)
      end

      it 'does not try to create a database' do
        expect(Database).not_to receive(:create)
        begin
          described_class.create(guid: 'Very$%$%#$BAD--__,,guid', plan_guid: plan_id)
        rescue RuntimeError
        end
      end
    end
  end

  describe '.destroy' do
    context 'when there is an instance with the given guid' do
      before do
        described_class.create(guid: instance_id, plan_guid: 'some-plan-guid')
      end

      it 'removes the ServiceInstance from the broker database' do
        expect { described_class.destroy(guid: instance_id) }.
          to change(ServiceInstance, :count).from(1).to(0)
      end

      it 'drops the MySQL database' do
        expect(Database.exists?(database_name)).to eq true
        described_class.destroy(guid: instance_id)
        expect(Database.exists?(database_name)).to eq false
      end
    end

    context 'when there is no instance with the given guid' do
      it 'raises an error' do
        expect {
          described_class.destroy(guid: instance_id)
        }.to raise_error(ServiceInstanceManager::ServiceInstanceNotFound)
      end

      it 'does not attempt to drop any databases' do
        expect(Database).not_to receive(:drop)
        begin
          described_class.destroy(guid: instance_id)
        rescue ServiceInstanceManager::ServiceInstanceNotFound
        end
      end
    end
  end
end
