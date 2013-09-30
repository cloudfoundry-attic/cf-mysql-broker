module ControllerHelpers
  extend ActiveSupport::Concern

  def authenticate
    username = 'test'
    password = Settings.auth_token

    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
  end
end

RSpec.configure do |config|
  config.include ControllerHelpers, type: :controller
end
