module Manage
  class AuthController < ApplicationController
    protect_from_forgery with: :exception, only: :destroy

    def create
      auth                        = request.env['omniauth.auth'].to_hash
      credentials                 = auth['credentials']

      token = credentials['token']
      if token.empty?
        return render 'errors/approvals_error'
      end

      raw_info = auth['extra']['raw_info']
      unless raw_info
        return render 'errors/approvals_error'
      end

      session[:uaa_user_id]       = auth['extra']['raw_info']['user_id']
      session[:uaa_access_token]  = credentials['token']
      session[:uaa_refresh_token] = credentials['refresh_token']
      session[:last_seen]         = Time.now

      redirect_to manage_instance_path(session[:instance_id])
    end

    def failure
      render plain: message_param[:message], status: 403
    end

    def destroy
     session.clear
     redirect_to ::Configuration.auth_server_logout_url
    end

    private

    def message_param
      params.permit(:message)
    end
  end
end
