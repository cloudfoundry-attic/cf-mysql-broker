require 'spec_helper'

describe ServiceInstance do
  let(:plan_guid_1) { '8888-ffff' }
  let(:max_storage_mb_1) { 8 }
  let(:plan_guid_2) { '4444-ffff' }
  let(:max_storage_mb_2) { 4 }

  let(:instance_guid_1) { 'instance-guid-1' }
  let(:instance_guid_2) { 'instance-guid-2' }

  before do
    allow(Catalog).to receive(:has_plan?).with(plan_guid_1).and_return(true)
    allow(Catalog).to receive(:has_plan?).with(plan_guid_2).and_return(true)

    allow(Catalog).to receive(:storage_quota_for_plan_guid).with(plan_guid_1).and_return(max_storage_mb_1)
    allow(Catalog).to receive(:storage_quota_for_plan_guid).with(plan_guid_2).and_return(max_storage_mb_2)
  end

  describe '.reserved_space_in_mb' do
    it 'returns 0 when no instances have been created' do
      expect(ServiceInstance.reserved_space_in_mb).to eq 0
    end

    it 'returns the sum of max_storage_mb for all existing instances' do
      ServiceInstanceManager.create(guid: instance_guid_1, plan_guid: plan_guid_1)
      ServiceInstanceManager.create(guid: instance_guid_2, plan_guid: plan_guid_2)

      expect(ServiceInstance.reserved_space_in_mb).to eq 12
    end
  end
end
