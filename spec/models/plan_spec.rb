require 'spec_helper'

describe Plan do
  describe '.build' do
    it 'sets the attributes correctly' do
      plan = Plan.build(
        'id'                   => 'plan_id',
        'name'                 => 'plan_name',
        'description'          => 'plan_description',
        'metadata'             => { 'meta_key' => 'meta_value' },
        'max_storage_mb'       => 50,
        'max_user_connections' => 5,
        'free'                 => false,
      )

      expect(plan.id).to eq('plan_id')
      expect(plan.name).to eq('plan_name')
      expect(plan.description).to eq('plan_description')
      expect(plan.metadata).to eq({ 'meta_key' => 'meta_value' })
      expect(plan.max_storage_mb).to eq(50)
      expect(plan.max_user_connections).to eq(5)
      expect(plan.free).to be false
    end

    context 'when the id key is missing' do
      it 'raises an error' do
        expect {
          Plan.build(
            'name'                 => 'plan_name',
            'description'          => 'plan_description',
            'metadata'             => { 'meta_key' => 'meta_value' },
            'max_storage_mb'       => 50,
            'max_user_connections' => 5,
            'free'                 => false,
          )
        }.to raise_error(KeyError, 'key not found: "id"')
      end
    end

    context 'when the name key is missing' do
      it 'raises an error' do
        expect {
          Plan.build(
            'id'                   => 'plan_id',
            'description'          => 'plan_description',
            'metadata'             => { 'meta_key' => 'meta_value' },
            'max_storage_mb'       => 50,
            'max_user_connections' => 5,
            'free'                 => false,
          )
        }.to raise_error(KeyError, 'key not found: "name"')
      end
    end

    context 'when the description key is missing' do
      it 'raises an error' do
        expect {
          Plan.build(
            'id'                   => 'plan_id',
            'name'                 => 'plan_name',
            'metadata'             => { 'meta_key' => 'meta_value' },
            'max_storage_mb'       => 50,
            'max_user_connections' => 5,
            'free'                 => false,
          )
        }.to raise_error(KeyError, 'key not found: "description"')
      end
    end

    context 'when the metadata key is missing' do
      let(:plan) do
        Plan.build(
          'id'                   => 'plan_id',
          'name'                 => 'plan_name',
          'description'          => 'plan_description',
          'max_storage_mb'       => 50,
          'max_user_connections' => 5,
          'free'                 => false,
        )
      end

      it 'sets the field to nil' do
        expect(plan.metadata).to be_nil
      end
    end

    context 'when the max_storage_mb key is missing' do
      let(:plan) do
        Plan.build(
          'id'                    => 'plan_id',
          'name'                  => 'plan_name',
          'description'           => 'plan_description',
          'metadata'              => { 'meta_key' => 'meta_value' },
          'max_user_connections'  => 5,
          'free'                  => false,
        )
      end

      it 'sets the field to nil' do
        expect(plan.max_storage_mb).to be_nil
      end
    end

    context 'when the max_user_connections key is missing' do
      let(:plan) do
        Plan.build(
          'id'              => 'plan_id',
          'name'            => 'plan_name',
          'description'     => 'plan_description',
          'metadata'        => { 'meta_key' => 'meta_value' },
          'max_storage_mb'  => 50,
          'free'            => false,
        )
      end

      it 'sets the field to nil' do
        expect(plan.max_user_connections).to be_nil
      end
    end

    context 'when the free key is missing' do
      let(:plan) do
        Plan.build(
          'id'                    => 'plan_id',
          'name'                  => 'plan_name',
          'description'           => 'plan_description',
          'metadata'              => { 'meta_key' => 'meta_value' },
          'max_storage_mb'        => 50,
          'max_user_connections'  => 5,
        )
      end

      it 'sets the field to true' do
        expect(plan.free).to be true
      end
    end
  end

  describe '#to_hash' do
    it 'contains the correct values' do
      plan = Plan.new(
        'id'                    => 'plan_id',
        'name'                  => 'plan_name',
        'description'           => 'plan_description',
        'metadata'              => { 'key1' => 'value1' },
        'max_storage_mb'        => 50,
        'max_user_connections'  => 5,
        'free'                  => false,
      )

      expect(plan.to_hash.fetch('id')).to eq('plan_id')
      expect(plan.to_hash.fetch('name')).to eq('plan_name')
      expect(plan.to_hash.fetch('description')).to eq('plan_description')
      expect(plan.to_hash.fetch('metadata')).to eq({ 'key1' => 'value1' })
      expect(plan.to_hash.fetch('max_storage_mb')).to eq(50)
      expect(plan.to_hash.fetch('max_user_connections')).to eq(5)
      expect(plan.to_hash.fetch('free')).to be false
    end
  end
end
