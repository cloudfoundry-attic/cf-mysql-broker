class AccessTokenHandler
  attr_reader :access_token, :refresh_token

  def initialize(access_token, refresh_token)
    @access_token = access_token
    @refresh_token = refresh_token
  end

  def auth_header
    token_info.auth_header
  end

  private

  def client
    @client ||= CF::UAA::TokenIssuer.new(Configuration.auth_server_url,
                                         Settings.dashboard_client.id,
                                         Settings.dashboard_client.secret,
                                         { token_target: Configuration.token_server_url })
  end

  def token_info
    token_expired? ? refreshed_token_info : existing_token_info
  end

  def token_expired?
    header = existing_token_info.auth_header
    expiry = CF::UAA::TokenCoder.decode(header.split()[1], verify: false)[:expires_at]
    expiry.is_a?(Integer) && expiry <= Time.now.to_i
  end

  def existing_token_info
    CF::UAA::TokenInfo.new(access_token: access_token, token_type: 'bearer')
  end

  def refreshed_token_info
    client.refresh_token_grant(refresh_token)
  end

end
