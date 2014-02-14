require 'spec_helper'

describe Manage::InstancesController do

  describe 'show' do
    before do
      Settings.stub(:cc_api_uri) { 'http://api.example.com' }
    end

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

        session[:uaa_user_id] = 'some-user-id'
        session[:uaa_access_token] = '<access token>'
        session[:uaa_refresh_token] = '<refresh token>'
        token_handler = double(AccessTokenHandler, auth_header: 'bearer <token>')
        AccessTokenHandler.should_receive(:new).with('<access token>', '<refresh token>') { token_handler }
      end

      after { instance.destroy }

      context 'when the user has permissions to manage the instance' do
        before do
          stub_request(:get, 'http://api.example.com/v2/service_instances/abc-123/permissions').
            with(headers: { 'Authorization' => 'bearer <token>' }).
            to_return(body: JSON.generate({ manage: true }))
        end

        it 'displays the usage information for the given instance' do
          get :show, id: 'abc-123'
          expect(response.status).to eql(200)
          expect(response.body).to match(/10\.3 MB used/)
          expect(query).to have_received(:execute).once
        end
      end

      context 'when the user does not have permission to manage the instance' do
        before do
          stub_request(:get, 'http://api.example.com/v2/service_instances/abc-123/permissions').
            with(headers: { 'Authorization' => 'bearer <token>' }).
            to_return(body: JSON.generate({ manage: false }))
        end

        it 'displays a "not authorized" message' do
          get :show, id: 'abc-123'
          expect(response.status).to eql(200)
          expect(response.body).to match(/Not\ Authorized/)
          expect(query).not_to have_received(:execute)
        end
      end
    end
  end

end
