class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods
  include ActionController::MimeResponds
  include ActionController::ImplicitRender
end
