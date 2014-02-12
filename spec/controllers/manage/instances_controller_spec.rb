require 'spec_helper'

describe Manage::InstancesController do

  describe 'show' do
    context 'when the user is not authenticated' do
      it 'stores the instance id in the session and redirects to the auth endpoint' do
        get :show, id: 'abc-123'
        expect(session[:instance_id]).to eql('abc-123')
        expect(response.status).to eql(302)
        expect(response).to redirect_to('/manage/auth/cloudfoundry')
      end
    end

    context 'when the user is authenticated' do
      let(:query) { double(ServiceInstanceUsageQuery) }
      let(:instance) { ServiceInstance.new(id: 'abc-123') }

      before do
        instance.save
        allow(ServiceInstanceUsageQuery).to receive(:new).and_return(query)
        allow(query).to receive(:execute).and_return(10.3)
      end

      after { instance.destroy }

      it 'displays the usage information for the given instance' do
        session[:uaa_user_id] = 'some-user-id'
        get :show, id: 'abc-123'

        expect(response.status).to eql(200)
        expect(response.body).to match(/10\.3 MB used/)
        expect(query).to have_received(:execute).once
      end
    end
  end

end
