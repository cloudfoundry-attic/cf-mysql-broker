module Configuration
  extend self

  def auth_server_url
    cc_api_info["authorization_endpoint"]
  end

  def token_server_url
    cc_api_info["token_endpoint"]
  end

  def cc_api_info
    store[:cc_api_info] ||= JSON.parse(Net::HTTP.get(URI.parse("#{Settings.cc_api_url}/info")))
  end

  def store
    @store ||= {}
  end

  def clear
    store.clear
  end
end
