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
end
