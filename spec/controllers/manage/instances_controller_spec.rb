require 'spec_helper'

describe Manage::InstancesController do

  describe 'show' do
    render_views

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
      let(:token_handler) { double(AccessTokenHandler, auth_header: 'bearer <token>') }

      before do
        instance.save
        allow(ServiceInstanceUsageQuery).to receive(:new).and_return(query)
        allow(query).to receive(:execute).and_return(10.3)

        session[:uaa_user_id]       = 'some-user-id'
        session[:uaa_access_token]  = '<access token>'
        session[:uaa_refresh_token] = '<refresh token>'

        allow(AccessTokenHandler).to receive(:new).with('<access token>', '<refresh token>').and_return(token_handler)

        allow(token_handler).to receive(:access_token).and_return('new_access_token')
        allow(token_handler).to receive(:refresh_token).and_return('new_refresh_token')
      end

      after { instance.destroy }

      context 'when the user has permissions to manage the instance' do
        before do
          Settings.stub(:cc_api_uri) { 'http://api.example.com' }

          allow(ServiceInstanceAccessVerifier).to receive(:can_manage_instance?).
                                                    with('abc-123', anything).
                                                    and_return(true)
        end

        it 'updates the session tokens' do
          get :show, id: 'abc-123'

          expect(session[:uaa_access_token]).to eql('new_access_token')
          expect(session[:uaa_refresh_token]).to eql('new_refresh_token')
        end

        it 'displays the usage information for the given instance' do
          quota = Settings.services[0].plans[0].max_storage_mb.to_i

          get :show, id: 'abc-123'

          expect(response.status).to eql(200)
          expect(response.body).to match(/10\.3 MB of #{quota} MB used./)
          expect(query).to have_received(:execute).once
        end

        context 'when the user is over the quota' do
          before do
            allow(query).to receive(:execute).and_return(120)
          end
          it 'displays a warning' do
            get :show, id: 'abc-123'
            expect(response.body).to include("Warning:")
          end
        end
      end

      context 'when the user does not have permission to manage the instance' do
        before do
          allow(ServiceInstanceAccessVerifier).to receive(:can_manage_instance?).
                                                    with('abc-123', anything).
                                                    and_return(false)
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
