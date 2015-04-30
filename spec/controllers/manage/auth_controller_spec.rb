require 'spec_helper'

describe Manage::AuthController do

  describe '#create' do
    let(:instance_id) { 'abc-123' }

    before do
      session[:instance_id] = instance_id
      request.env['omniauth.auth'] = {
        'extra' => extra,
        'credentials' => credentials
      }
    end

    context 'when access token, refresh token, and user_id are present' do
      let(:extra) {
        {
          'raw_info' => {
            'user_id' => 'mister_tee'
          }
        }
      }

      let(:credentials) {
        {
          'token' => 'UAA access token',
          'refresh_token' => 'UAA refresh token'
        }
      }

      it 'authenticates the user based on the permissions from UAA' do
        get :create, some: 'stuff'
        expect(response.status).to eql(302)
        expect(response).to redirect_to(manage_instance_path(instance_id))

        expect(session[:uaa_user_id]).to eql('mister_tee')
        expect(session[:uaa_access_token]).to eql('UAA access token')
        expect(session[:uaa_refresh_token]).to eql('UAA refresh token')
        expect(session[:last_seen]).to be_a_kind_of(Time)
      end
    end

    context 'when omniauth does not yield an access token' do
      let(:extra) {
        {
          'raw_info' => {
            'user_id' => 'mister_tee'
          }
        }
      }

      let(:credentials) {
        {
          'token' => '',
          'refresh_token' => '',
          'authorized_scopes' => ''
        }
      }

      it 'renders the approvals error page' do
        get :create, some: 'stuff'

        expect(response.status).to eql(200)
        expect(response).to render_template 'errors/approvals_error'
      end
    end

    context 'when omniauth does not yield user info (raw_info)' do
      let(:extra) {
        {}
      }

      let(:credentials) {
        {
          'token' => 'access token',
          'refresh_token' => 'refresh token',
          'authorized_scopes' => 'scope.yay'
        }
      }

      it 'renders the approvals error page' do
        get :create, some: 'stuff'

        expect(response.status).to eql(200)
        expect(response).to render_template 'errors/approvals_error'
      end
    end
  end

  describe '#failure' do
    it 'returns a 403 status code' do
      get :failure
      expect(response.status).to eql(403)
    end

    it 'echos the passed message param as the failure message' do
      get :failure, message: 'something broke'
      expect(response.body).to eq 'something broke'
    end
  end
end
