module Manage
  class InstancesController < ActionController::Base

    before_filter :require_login
    before_filter :build_uaa_session
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

    def build_uaa_session
      @uaa_session = UaaSession.build(session[:uaa_access_token], session[:uaa_refresh_token])
      session[:uaa_access_token]  = @uaa_session.access_token
    end

    def ensure_can_manage_instance
      cc_client = CloudControllerHttpClient.new(Settings.cc_api_uri, @uaa_session.auth_header)
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
