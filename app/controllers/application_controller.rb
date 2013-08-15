class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods
end
