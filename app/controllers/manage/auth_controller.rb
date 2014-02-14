module Manage
  class AuthController < ActionController::Base

    def create
      auth = request.env['omniauth.auth'].to_hash
      session[:uaa_user_id] = auth['extra']['raw_info']['user_id']
      credentials = auth['credentials']
      session[:uaa_access_token] = credentials['token']
      session[:uaa_refresh_token] = credentials['refresh_token']
      redirect_to manage_instance_path(session[:instance_id])
    end

    def failure
      render text: params[:message], status: 403
    end

  end
end
