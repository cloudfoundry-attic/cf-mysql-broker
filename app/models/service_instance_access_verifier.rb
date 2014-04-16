class ServiceInstanceAccessVerifier
  class << self
    def can_manage_instance?(instance_guid, cc_client)
      response_body = cc_client.get("/v2/service_instances/#{instance_guid}/permissions")
      !response_body.nil? && response_body['manage']
    end
  end
end
