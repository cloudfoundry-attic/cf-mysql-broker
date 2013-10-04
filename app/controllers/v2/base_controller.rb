class V2::BaseController < ApplicationController
  before_filter :authenticate

  respond_to :json

  self.responder = ApiResponder

  protected

  def authenticate
    authenticate_or_request_with_http_basic do |_, password|
      password == Settings.auth_token
    end
  end
end
