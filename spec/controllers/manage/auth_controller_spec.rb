require 'spec_helper'

describe Manage::AuthController do

  describe '#create' do
    let(:instance_id) { 'abc-123' }

    before do
      session[:instance_id] = instance_id
      request.env['omniauth.auth'] = {
        'extra' => {
          'raw_info' => {
            'user_id' => 'mister_tee'
          }
        }
      }
    end

    it 'authenticates the user based on the permissions from UAA' do
      get :create, some: 'stuff'

      expect(response.status).to eql(302)
      expect(response).to redirect_to(manage_instance_path(instance_id))

      expect(session[:uaa_user_id]).to eql('mister_tee')
    end
  end

  describe '#failure' do
    it 'returns a 403 status code' do
      get :failure
      expect(response.status).to eql(403)
    end
  end

end
