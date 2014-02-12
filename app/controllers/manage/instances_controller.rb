module Manage
  class InstancesController < ActionController::Base

    def show
      session[:instance_id] = params[:id]

      if logged_in?
        instance = ServiceInstance.find(params[:id])
        usage    = ServiceInstanceUsageQuery.new(instance).execute
        render text: "#{usage} MB used."
      else
        redirect_to '/manage/auth/cloudfoundry'
      end
    end

    private

    def logged_in?
      session[:uaa_user_id].present?
    end

  end
end
