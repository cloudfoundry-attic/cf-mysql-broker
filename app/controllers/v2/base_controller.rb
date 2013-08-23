class V2::BaseController < ApplicationController
  before_filter :authenticate

  protected

  def authenticate
    authenticate_or_request_with_http_basic do |_, password|
      password == ENV['AUTH_TOKEN']
    end
  end
end
