require 'spec_helper'

describe Plan do
  describe '.build' do
    it 'sets the attributes correctly' do
      plan = Plan.build(
        'id'              => 'plan_id',
        'name'            => 'plan_name',
        'description'     => 'plan_description',
        'metadata'        => { 'meta_key' => 'meta_value' },
        'max_storage_mb'  => 5,
        'max_user_connections' => 5
      )

      expect(plan.id).to eq('plan_id')
      expect(plan.name).to eq('plan_name')
      expect(plan.description).to eq('plan_description')
      expect(plan.metadata).to eq({ 'meta_key' => 'meta_value' })
      expect(plan.max_storage_mb).to eq(5)
      expect(plan.max_user_connections).to eq(5)
    end

    context 'when the metadata key is missing' do
      let(:plan) do
        Plan.build(
          'id'          => 'plan_id',
          'name'        => 'plan_name',
          'description' => 'plan_description',
          'max_storage_mb'  => 5
        )
      end

      it 'sets the field to nil' do
        expect(plan.metadata).to be_nil
      end
    end

    context 'when the max_storage_mb key is missing' do
      let(:plan) do
        Plan.build(
            'id'          => 'plan_id',
            'name'        => 'plan_name',
            'description' => 'plan_description',
            'metadata'        => { 'meta_key' => 'meta_value' },
        )
      end

      it 'sets the field to nil' do
        expect(plan.max_storage_mb).to be_nil
      end
    end

    context 'when the max_user_connections key is missing' do
      let(:plan) do
        Plan.build(
          'id'          => 'plan_id',
          'name'        => 'plan_name',
          'description' => 'plan_description',
          'metadata'        => { 'meta_key' => 'meta_value' },
        )
      end

      it 'sets the field to nil' do
        expect(plan.max_user_connections).to be_nil
      end
    end
  end

  describe '#to_hash' do
    it 'contains the correct values' do
      plan = Plan.new(
        'id'          => 'plan_id',
        'name'        => 'plan_name',
        'description' => 'plan_description',
        'metadata'    => { 'key1' => 'value1' }
      )

      expect(plan.to_hash.fetch('id')).to eq('plan_id')
      expect(plan.to_hash.fetch('name')).to eq('plan_name')
      expect(plan.to_hash.fetch('description')).to eq('plan_description')
      expect(plan.to_hash.fetch('metadata')).to eq({ 'key1' => 'value1' })
    end
  end
end
