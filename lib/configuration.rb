module Configuration
  extend self

  def documentation_url
    Settings.services.first.metadata.documentationUrl rescue nil
  end

  def support_url
    Settings.services.first.metadata.supportUrl rescue nil
  end

  def manage_user_profile_url
    "#{auth_server_url}/profile"
  end

  def auth_server_url
    cc_api_info["authorization_endpoint"]
  end

  def token_server_url
    cc_api_info["token_endpoint"]
  end

  def cc_api_info
    store[:cc_api_info] ||= JSON.parse(Net::HTTP.get(URI.parse("#{Settings.cc_api_uri}/info")))
  end

  def store
    @store ||= {}
  end

  def clear
    store.clear
  end
end
