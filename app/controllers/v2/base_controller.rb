class V2::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  before_filter :authenticate
  before_filter :log_headers_and_body

  protected

  def authenticate
    authenticate_or_request_with_http_basic do |username, password|
      username == Settings.auth_username &&
        password == Settings.auth_password
    end
  end

  private

  def log_headers_and_body
    RequestLogger.new(logger).log_headers_and_body(request.env, request.body.read)
  end
end
