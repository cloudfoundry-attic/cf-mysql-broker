module Manage
  class InstancesController < ActionController::Base

    def show
      session[:instance_id] = params[:id]

      if logged_in?
        instance = ServiceInstance.find(params[:id])
        if can_manage_instance?(instance)
          render text: "#{ServiceInstanceUsageQuery.new(instance).execute} MB used."
        else
          render text: 'Not Authorized'
        end
      else
        redirect_to '/manage/auth/cloudfoundry'
      end
    end

    private

    def logged_in?
      session[:uaa_user_id].present?
    end

    def can_manage_instance?(instance)
      uri = URI.parse("#{Settings.cc_api_uri}/v2/service_instances/#{instance.id}/permissions")

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == 'https'

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = AccessTokenHandler.new(session[:uaa_access_token], session[:uaa_refresh_token]).auth_header

      response = http.request(request)

      JSON.parse(response.body)['manage']
    end
  end
end
