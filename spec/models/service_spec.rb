require 'spec_helper'

describe Service do
  describe '.build' do
    before do
      allow(Plan).to receive(:build)
    end

    it 'sets fields correct' do
      service = Service.build(
        'id'          => 'my-id',
        'name'        => 'my-name',
        'description' => 'my description',
        'tags'        => ['tagA', 'tagB'],
        'metadata'    => { 'stuff' => 'goes here' },
        'plans'       => []
      )
      expect(service.id).to eq('my-id')
      expect(service.name).to eq('my-name')
      expect(service.description).to eq('my description')
      expect(service.tags).to eq(['tagA', 'tagB'])
      expect(service.metadata).to eq({ 'stuff' => 'goes here' })
    end

    it 'is bindable' do
      service = Service.build(
        'id'          => 'my-id',
        'name'        => 'my-name',
        'description' => 'my description',
        'tags'        => ['tagA', 'tagB'],
        'metadata'    => { 'stuff' => 'goes here' },
        'plans'       => []
      )

      expect(service).to be_bindable
    end

    it 'builds plans and sets the plans field' do
      plan_attrs = [double(:plan_attr1), double(:plan_attr2)]
      plan1      = double(:plan1)
      plan2      = double(:plan2)

      allow(Plan).to receive(:build).with(plan_attrs[0]).and_return(plan1)
      allow(Plan).to receive(:build).with(plan_attrs[1]).and_return(plan2)

      service = Service.build(
        'plans'       => plan_attrs,
        'id'          => 'my-id',
        'name'        => 'my-name',
        'description' => 'my description',
        'tags'        => ['tagA', 'tagB'],
        'metadata'    => { 'stuff' => 'goes here' },
      )

      expect(service.plans).to eq([plan1, plan2])
    end

    context 'when the metadata attr is missing' do
      let(:service) do
        Service.build(
          'id'          => 'my-id',
          'name'        => 'my-name',
          'description' => 'my description',
          'tags'        => ['tagA', 'tagB'],
          'plans'       => []
        )
      end

      it 'sets the field to nil' do
        expect(service.metadata).to be_nil
      end
    end

    context 'when the tags attr is missing' do
      let(:service) do
        Service.build(
          'id'          => 'my-id',
          'name'        => 'my-name',
          'description' => 'my description',
          'metadata'    => { 'stuff' => 'goes here' },
          'plans'       => []
        )
      end

      it 'sets the field to an empty array' do
        expect(service.tags).to eq([])
      end
    end
  end

  describe '#to_hash' do
    it 'contains the right values' do
      service = Service.new(
        'id'          => 'my-id',
        'name'        => 'my-name',
        'description' => 'my-description',
        'tags'        => ['tagA', 'tagB'],
        'metadata'    => { 'meta' => 'data' },
        'plans'       => []
      )

      expect(service.to_hash.fetch('id')).to eq('my-id')
      expect(service.to_hash.fetch('name')).to eq('my-name')
      expect(service.to_hash.fetch('bindable')).to eq(true)
      expect(service.to_hash.fetch('description')).to eq('my-description')
      expect(service.to_hash.fetch('tags')).to eq(['tagA', 'tagB'])
      expect(service.to_hash.fetch('metadata')).to eq({ 'meta' => 'data' })
      expect(service.to_hash).to have_key('plans')
    end

    it 'includes the #to_hash for each plan' do
      plan_1         = double(:plan_1)
      plan_2         = double(:plan_2)
      plan_1_to_hash = double(:plan_1_to_hash)
      plan_2_to_hash = double(:plan_2_to_hash)

      expect(plan_1).to receive(:to_hash).and_return(plan_1_to_hash)
      expect(plan_2).to receive(:to_hash).and_return(plan_2_to_hash)

      service = Service.new(
        'plans'       => [plan_1, plan_2],
        'id'          => 'my-id',
        'name'        => 'my-name',
        'description' => 'my-description',
        'tags'        => ['tagA', 'tagB'],
        'metadata'    => { 'meta' => 'data' },
      )

      expect(service.to_hash.fetch('plans')).to eq([plan_1_to_hash, plan_2_to_hash])
    end

    context 'when there is no plans key' do
      let(:service) do
        Service.new(
          'id'          => 'my-id',
          'name'        => 'my-name',
          'description' => 'my-description',
          'tags'        => ['tagA', 'tagB'],
          'metadata'    => { 'meta' => 'data' },
        )
      end

      it 'has an empty list of plans' do
        expect(service.to_hash.fetch('plans')).to eq([])
      end
    end
  end
end