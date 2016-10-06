shared_examples_for 'a controller action that does not log its request and response headers and body' do
  it 'does not log the request' do
    expect(Rails.logger).to_not receive(:info).with(/Request:/)
    make_request
  end

  it 'does not log the response' do
    expect(Rails.logger).to_not receive(:info).with(/Response:/)
    make_request
  end
end

shared_examples_for 'a controller action that requires basic auth' do
  context 'when the basic-auth username is incorrect' do
    before do
      set_basic_auth('wrong_username', Settings.auth_password)
    end

    it 'responds with a 401' do
      make_request

      expect(response.status).to eq(401)
    end
  end
end

module ControllerHelpers
  extend ActiveSupport::Concern

  def authenticate
    set_basic_auth(Settings.auth_username, Settings.auth_password)
  end

  def set_basic_auth(username, password)
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
  end

  def db
    ActiveRecord::Base.connection
  end
end

RSpec.configure do |config|
  config.include ControllerHelpers, type: :controller
  config.infer_spec_type_from_file_location!
end
