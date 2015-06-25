require 'spec_helper'

describe Manage::InstancesController do

  describe 'show' do
    render_views

    before do
      allow(Settings).to receive(:ssl_enabled).and_return(false)
      allow(Settings).to receive(:cc_api_uri) { 'http://api.example.com' }
      allow(CF::UAA::TokenCoder).to receive(:decode).and_return('scope' => ['openid', 'cloud_controller_service_permissions.read'])
    end

    describe 'redirecting a user that is not logged in' do
      context 'when there is no session' do
        it 'redirects the user' do
          get :show, id: 'abc-123'
          expect(response).to redirect_to('/manage/auth/cloudfoundry')
        end
      end

      context 'when there is a session with a uaa_user_id' do
        let(:expiry) { 5 } #seconds
        before do
          allow(Settings).to receive(:session_expiry).and_return(expiry)

          session[:uaa_user_id]       = 'some-user-id'
          session[:uaa_access_token]  = '<access token>'
          session[:uaa_refresh_token] = '<refresh token>'
        end

        context 'when the last_seen is old' do
          before do
            session[:last_seen] = Time.now - (expiry+1)
          end

          it 'redirects to auth' do
            get :show, id: 'abc-123'
            expect(response).to redirect_to('/manage/auth/cloudfoundry')
          end
        end
      end
    end

    describe 'the dashboard redirects depending on ssl_enabled setting' do

      let(:instance) { ServiceInstance.new(id: 'abc-123') }
      let(:uaa_session) { double(UaaSession, auth_header: 'bearer <token>', refresh_token: 'new_refresh_token') }

      before do
        instance.save

        session[:uaa_user_id]       = 'some-user-id'
        session[:uaa_access_token]  = '<access token>'
        session[:uaa_refresh_token] = '<refresh token>'
        session[:last_seen]         = Time.now

        allow(UaaSession).to receive(:build).with('<access token>', '<refresh token>').and_return(uaa_session)

        allow(uaa_session).to receive(:access_token).and_return('new_access_token')

        allow(ServiceInstanceAccessVerifier).to receive(:can_manage_instance?)
      end

      after { instance.destroy }

      context 'when ssl_enabled is false' do
        before do
          allow(Settings).to receive(:ssl_enabled).and_return(false)
        end

        it 'does not redirect http requests to https' do
          @request.env['HTTPS'] = nil
          get :show, id: 'abc-123'
          expect(response.status).to eq 200
        end

        it 'does not redirect https requests' do
          @request.env['HTTPS'] = 'on'
          get :show, id: 'abc-123'
          expect(response.status).to eq 200
        end
      end

      context 'when ssl_enabled is true' do
        before do
          allow(Settings).to receive(:ssl_enabled).and_return(true)
        end

        it 'redirects http requests to https' do
          @request.env['HTTPS'] = nil
          get :show, id: 'abc-123'
          expect(response).to redirect_to("https://#{request.host}#{request.path_info}")
        end

        it 'does not redirect https requests' do
          @request.env['HTTPS'] = 'on'
          get :show, id: 'abc-123', ssl: true
          expect(response.status).to eq 200
        end
      end
    end

    describe 'verifying that the user has approved the necessary scopes' do
      let(:uaa_session) { double(UaaSession, auth_header: 'bearer <token>', refresh_token: 'new_refresh_token') }
      let(:all_scopes) { ['openid', 'cloud_controller_service_permissions.read'] }
      let(:missing_scopes) { ['openid'] }

      before do
        session[:uaa_user_id]       = 'some-user-id'
        session[:uaa_access_token]  = '<access token>'
        session[:uaa_refresh_token] = '<refresh token>'
        session[:last_seen]         = Time.now
        session[:has_retried]       = has_retried

        allow(UaaSession).to receive(:build).with('<access token>', '<refresh token>').and_return(uaa_session)

        allow(uaa_session).to receive(:access_token).and_return('new_access_token')
        allow(CF::UAA::TokenCoder).to receive(:decode).with('new_access_token', verify: false).and_return({'scope' => scopes} )

        allow(Configuration).to receive(:manage_user_profile_url).and_return('login.com/profile')
      end


      context 'when the user has not approved the necessary scopes' do
        let(:scopes) { missing_scopes }
        let(:has_retried) { 'true' }

        it 'renders the approval errors page' do
          get :show, id: 'abc-123'

          expect(response.status).to eq 200
          expect(response.body).to include('This application requires the following permissions')
        end
      end

      context 'when the user updates his approvals to include the necessary scopes' do
        context 'the first attempt that fails' do
          let(:scopes) { missing_scopes }
          let(:has_retried) { nil }

          it 'redirects to the auth endpoint' do
            get :show, id: 'abc-123'

            expect(response).to redirect_to '/manage/auth/cloudfoundry'
          end
        end
      end
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
      let(:instance) { ServiceInstance.new(guid: 'abc-123') }
      let(:uaa_session) { double(UaaSession, auth_header: 'bearer <token>') }

      before do
        instance.save
        allow(ServiceInstanceUsageQuery).to receive(:new).and_return(query)
        allow(query).to receive(:execute).and_return(10.3)

        session[:uaa_user_id]       = 'some-user-id'
        session[:uaa_access_token]  = '<access token>'
        session[:uaa_refresh_token] = '<refresh token>'
        session[:last_seen]         = Time.now

        allow(UaaSession).to receive(:build).with('<access token>', '<refresh token>').and_return(uaa_session)

        allow(uaa_session).to receive(:access_token).and_return('new_access_token')
        allow(uaa_session).to receive(:refresh_token).and_return('new_refresh_token')

        allow(ServiceInstanceAccessVerifier).to receive(:can_manage_instance?)
      end

      after { instance.destroy }

      it 'updates the last_seen' do
        expect {
          get(:show, id: 'abc-123')
        }.to change { session[:last_seen] }
      end

      context 'when the user has permissions to manage the instance' do
        before do
          Settings.stub(:cc_api_uri) { 'http://api.example.com' }

          allow(ServiceInstanceAccessVerifier).to receive(:can_manage_instance?).
                                                    with('abc-123', anything).
                                                    and_return(true)
        end

        it 'updates the uaa access token' do
          get :show, id: 'abc-123'

          expect(session[:uaa_access_token]).to eql('new_access_token')
        end

        it 'updates the uaa refresh token' do
          get :show, id: 'abc-123'

          expect(session[:uaa_refresh_token]).to eql('new_refresh_token')
        end

        it 'displays the usage information for the given instance' do
          quota = instance.max_storage_mb

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
