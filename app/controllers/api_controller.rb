class ApiController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods
end
