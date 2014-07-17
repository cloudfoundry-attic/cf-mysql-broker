require 'spec_helper'

describe ServiceCapacity do
  describe '.can_allocate?' do
    before do
      allow(Settings).to receive(:[]).with('persistent_disk').and_return(1000)
      allow(Settings).to receive(:[]).with('gcache_size').and_return(10)
      allow(Settings).to receive(:[]).with('ib_log_file_size').and_return(5)
      allow(ServiceInstance).to receive(:reserved_space_in_mb).and_return(900)
      allow(ServiceBinding).to receive(:count).and_return(10)
      ServiceInstance.stub_chain(:all, :count).and_return(5)
    end

    it 'returns true when the allocated space + requested space is < the storage capacity' do
      expect(described_class.can_allocate?(15)).to eq true
    end

    it 'returns true when the allocated space + requested space is = the storage capacity' do
      expect(described_class.can_allocate?(15.947)).to eq true
    end

    it 'returns false when the allocated space + requested space is > the storage capacity' do
      expect(described_class.can_allocate?(15.948)).to eq false
    end
  end
end
