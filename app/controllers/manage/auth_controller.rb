module Manage
  class AuthController < ActionController::Base

    def create
      session[:uaa_user_id] = request.env['omniauth.auth'].to_hash['extra']['raw_info']['user_id']
      redirect_to manage_instance_path(session[:instance_id])
    end

    def failure
      render text: params[:message], status: 403
    end

  end
end
