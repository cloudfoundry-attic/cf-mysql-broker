module ControllerHelpers
  extend ActiveSupport::Concern

  included do
    before do
      @__original_auth_token, ENV['AUTH_TOKEN'] = ENV['AUTH_TOKEN'], 'secret'
    end

    after do
      ENV['AUTH_TOKEN'], @__original_auth_token = @__original_auth_token, nil
    end
  end

  def authenticate
    username = 'test'
    password = 'secret'

    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
  end
end

RSpec.configure do |config|
  config.include ControllerHelpers, type: :controller
end
