require 'spec_helper'

describe ServiceInstanceAccessVerifier do
  let(:http_client) { double(CloudControllerHttpClient, get: {}) }
  let(:instance_guid) { 'an-instance-guid'}

  describe '#can_manage_instance?' do
    it 'makes a request to CC' do
      ServiceInstanceAccessVerifier.can_manage_instance?(instance_guid, http_client)
      expect(http_client).to have_received(:get).with("/v2/service_instances/#{instance_guid}/permissions")
    end

    context 'when the user does not approve cloud_controller_service_permissions.read' do
      before do
        allow(http_client).to receive(:get).and_return(nil)
      end

      it 'returns false' do
        expect(ServiceInstanceAccessVerifier.can_manage_instance?(instance_guid, http_client)).to eql(false)
      end
    end

    context 'when the user can manage the service instance' do
      before do
        allow(http_client).to receive(:get).and_return({'manage' => true})
      end
      it 'returns true' do
        expect(ServiceInstanceAccessVerifier.can_manage_instance?(instance_guid, http_client)).to eql(true)
      end
    end

    context "when the user can't manage the service instance" do
      before do
        allow(http_client).to receive(:get).and_return({'manage' => false})
      end
      it 'returns false' do
        expect(ServiceInstanceAccessVerifier.can_manage_instance?(instance_guid, http_client)).to eql(false)
      end
    end
  end
end
