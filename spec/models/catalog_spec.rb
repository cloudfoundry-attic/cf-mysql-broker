require 'spec_helper'

describe Catalog do
  let(:services) {
    [
        service_1_attrib,
        service_2_attrib
    ]
  }
  let(:service_1_attrib) {
    {
        'id' => 'foo',
        'name' => 'bar',
        'description' => 'desc',
        'bindable' => true,
        'plans' => [
            plan_1_attrib,
            plan_2_attrib
        ]
    }
  }
  let(:service_2_attrib) {
    {
        'id' => 'foo2',
        'name' => 'bar2',
        'description' => 'desc2',
        'bindable' => true,
        'plans' => [
            plan_3_attrib
        ]
    }
  }
  let(:plan_1_attrib) {
    {
        'id' => 'plan_id_1',
        'name' => 'plan_name_1',
        'description' => 'desc1',
        'max_storage_mb' => 5,
        'max_user_connections' => 7,
    }
  }
  let(:plan_2_attrib) {
    {
        'id' => 'plan_id_2',
        'name' => 'plan_name_2',
        'description' => 'desc2',
        'max_storage_mb' => 100,
        'max_user_connections' => 40,
    }
  }
  let(:plan_3_attrib) {
    {
        'id' => 'plan_id_3',
        'name' => 'plan_name_3',
        'description' => 'desc3',
        'max_storage_mb' => 101,
        'max_user_connections' => 41,
    }
  }

  before do
    Settings.stub(:[]).with('services').and_return(services)
  end

  describe '.plans' do
    it 'returns an array of plan objects representing the plans in the catalog' do
      catalog_plans = Catalog.plans.map(&:to_hash)
      expected_plans = [
          Plan.build(plan_1_attrib),
          Plan.build(plan_2_attrib),
          Plan.build(plan_3_attrib)
      ].map(&:to_hash)

      expect(catalog_plans).to match_array expected_plans
    end
  end

  describe '.storage_quota_for_plan_guid' do
    it 'returns max_storage_mb for the plan with the specified guid' do
      expect(Catalog.storage_quota_for_plan_guid('plan_id_2')).to eq(100)
    end

    context 'when the plan with the guid is not found' do
      it 'returns nil' do
        expect(Catalog.storage_quota_for_plan_guid('non-existent-plan')).to be_nil
      end
    end
  end

  describe '.connection_quota_for_plan_guid' do
    it 'returns max_user_connections for the plan with the specified guid' do
      expect(Catalog.connection_quota_for_plan_guid('plan_id_2')).to eq(40)
    end

    context 'when the plan with the guid is not found' do
      it 'returns nil' do
        expect(Catalog.connection_quota_for_plan_guid('non-existent-plan')).to be_nil
      end
    end
  end

  describe '.has_plan?' do
    it 'returns true if plan_id exists in the catalog' do
      expect(Catalog.has_plan?('plan_id_2')).to be_true
    end

    it 'returns false if plan_id does not exist in the catalog' do
      expect(Catalog.has_plan?('plan_id_banana')).to be_false
    end

    context 'when there are no services' do
      let(:services) { [] }

      it 'returns false' do
        expect(Catalog.has_plan?('any-plan')).to be_false
      end
    end
  end
end
