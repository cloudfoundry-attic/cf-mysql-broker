require 'spec_helper'

describe ServiceInstanceManager do
  let(:instance_id) { '88f6fa22-c8b7-4cdc-be3a-dc09ea7734db' }
  let(:database_name) { 'cf_88f6fa22_c8b7_4cdc_be3a_dc09ea7734db' }
  let(:plan_id) { '8888-ffff' }
  let(:non_existent_plan_id) { 'non-existent-guid' }
  let(:max_storage_mb) { 300 }

  before do
    Catalog.stub(:has_plan?).with(plan_id).and_return(true)
    Catalog.stub(:has_plan?).with(non_existent_plan_id).and_return(false)
    Catalog.stub(:storage_quota_for_plan_guid).with(plan_id).and_return(max_storage_mb)
  end

  describe '.database_name_from_service_instance_guid' do
    it 'converts instance_id to database_name' do
      expect(ServiceInstanceManager.database_name_from_service_instance_guid(instance_id)).to eq(database_name)
    end
  end

  describe '.create' do
    after {
      Database.drop(database_name)
    }

    it 'saves a ServiceInstance in the broker database' do
      expect { described_class.create(guid: instance_id, plan_guid: plan_id) }.
          to change(ServiceInstance, :count).from(0).to(1)
      expect(ServiceInstance.last.guid).to eq(instance_id)
      expect(ServiceInstance.last.plan_guid).to eq(plan_id)
      expect(ServiceInstance.last.max_storage_mb).to eq (max_storage_mb)
      expect(ServiceInstance.last.db_name).to eq (database_name)
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

    context 'when the plan guid is not in the catalog' do

      it 'raises an error' do
        expect {
          described_class.create(guid: instance_id, plan_guid: non_existent_plan_id)
        }. to raise_error(RuntimeError, "Plan #{non_existent_plan_id} was not found in the catalog.")
      end

      it 'does not save a ServiceInstance in the broker database' do
        expect {
          begin
            described_class.create(guid: instance_id, plan_guid: non_existent_plan_id)
          rescue RuntimeError
          end
        }.not_to change(ServiceInstance, :count)
      end

      it 'does not try to create a database' do
        expect(Database).not_to receive(:create)
        begin
          described_class.create(guid: instance_id, plan_guid: non_existent_plan_id)
        rescue RuntimeError
        end
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

  describe '.set_plan' do
    let(:new_plan_id) { 'new-plan-id' }
    let!(:service_instance) { described_class.create(guid: instance_id, plan_guid: plan_id) }

    before do
      Catalog.stub(:has_plan?).with(new_plan_id).and_return(true)
      Catalog.stub(:storage_quota_for_plan_guid).with(new_plan_id).and_return(12)
    end

    it 'changes the plan_guid' do
      described_class.set_plan(guid: instance_id, plan_guid: new_plan_id)
      service_instance.reload
      expect(service_instance.plan_guid).to eq new_plan_id
      expect(service_instance.max_storage_mb).to eq 12
    end

    context 'when there is no plan with the given guid' do
      it 'raises a ServiceInstanceManager::ServicePlanNotFound error' do
        expect { described_class.set_plan(guid: instance_id, plan_guid: non_existent_plan_id) }.to raise_error(ServiceInstanceManager::ServicePlanNotFound)
      end
    end

    context 'when there is no instance with the given guid' do
      let!(:service_instance) { nil }
      it 'raises a ServiceInstanceManager::ServiceInstanceNotFound error' do
        expect { described_class.set_plan(guid: instance_id, plan_guid: new_plan_id) }.to raise_error(ServiceInstanceManager::ServiceInstanceNotFound)
      end
    end

    context 'when downgrading would put the databases over the quota limit of its new plan' do
      before do
        db_name = ServiceInstanceManager.database_name_from_service_instance_guid(instance_id)
        allow(Database).to receive(:usage).with(db_name).and_return 30
      end

      it 'raises an InvalidServicePlanUpdate error' do
        expect{ServiceInstanceManager.set_plan(guid: instance_id, plan_guid: new_plan_id)}.to raise_error(ServiceInstanceManager::InvalidServicePlanUpdate)
      end
    end
  end

  describe '.destroy' do
    context 'when there is an instance with the given guid' do
      before do
        described_class.create(guid: instance_id, plan_guid: plan_id)
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

  describe '.sync_service_instances' do
    context 'when the plan db size has changed' do
      it 'updates service instance plan sizes' do
        # create an instance of default size
        instance = described_class.create(guid: instance_id, plan_guid: plan_id)
        expect(instance.max_storage_mb).to eq max_storage_mb

        # increase plan size in Catalog
        new_plan_size = max_storage_mb + 100
        Catalog.stub(:plans).and_return([
            Plan.build('id' => plan_id,
                       'name' => 'plan_name',
                       'description' => 'plan description',
                       'max_storage_mb' => new_plan_size)
          ])

        # call sync_service_instances
        described_class.sync_service_instances

        # expect instance to have same guid but new plan size
        updated_instance = ServiceInstance.find_by(id: instance.id)
        expect(updated_instance.plan_guid).to eq instance.plan_guid
        expect(updated_instance.max_storage_mb).to eq new_plan_size
      end
    end
  end
end
