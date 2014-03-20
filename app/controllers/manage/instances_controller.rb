module Manage
  class InstancesController < ActionController::Base

    before_filter :require_login
    before_filter :store_token
    before_filter :ensure_can_manage_instance

    def show
      instance = ServiceInstance.find(params[:id])

      @used_data = ServiceInstanceUsageQuery.new(instance).execute
      @quota = QuotaEnforcer::QUOTA_IN_MB
      @over_quota = @used_data > @quota
    end

    private

    def require_login
      session[:instance_id] = params[:id]
      unless logged_in?
        redirect_to '/manage/auth/cloudfoundry'
        return false
      end
    end

    def store_token
      token_handler = AccessTokenHandler.new(session[:uaa_access_token], session[:uaa_refresh_token])
      session[:uaa_access_token]  = token_handler.access_token
      session[:uaa_refresh_token] = token_handler.refresh_token
      @auth_header   = token_handler.auth_header
    end

    def ensure_can_manage_instance
      cc_client = CloudControllerHttpClient.new(Settings.cc_api_uri, @auth_header)
      unless ServiceInstanceAccessVerifier.can_manage_instance?(params[:id], cc_client)
        render(text: 'Not Authorized')
        return false
      end
    end

    def logged_in?
      session[:uaa_user_id].present?
    end
  end
end
