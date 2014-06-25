require 'spec_helper'

describe ServiceCapacity do
  describe '.can_allocate?' do
    before do
      Settings.stub(:[]).with('storage_capacity_mb').and_return(1000)
    end

    it 'returns true when the allocated space + requested space is < the storage capacity' do
      ServiceInstance.stub(:reserved_space_in_mb).and_return(900)
      expect(described_class.can_allocate?(99)).to be_true
    end

    it 'returns true when the allocated space + requested space is = the storage capacity' do
      ServiceInstance.stub(:reserved_space_in_mb).and_return(900)
      expect(described_class.can_allocate?(100)).to be_true
    end

    it 'returns false when the allocated space + requested space is > the storage capacity' do
      ServiceInstance.stub(:reserved_space_in_mb).and_return(900)
      expect(described_class.can_allocate?(101)).to be_false
    end
  end
end
