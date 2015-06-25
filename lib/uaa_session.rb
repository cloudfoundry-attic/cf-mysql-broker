class UaaSession
  class << self
    def build(access_token, refresh_token)
      token_info = existing_token_info(access_token, refresh_token)
      if token_expired?(token_info)
        token_info = refreshed_token_info(refresh_token)
      end

      new(token_info)
    end

    private

    def token_expired?(token_info)
      header = token_info.auth_header
      expiry = CF::UAA::TokenCoder.decode(header.split()[1], verify: false)['exp']
      expiry.is_a?(Integer) && expiry <= Time.now.to_i
    end

    def existing_token_info(access_token, refresh_token)
      CF::UAA::TokenInfo.new(access_token: access_token,
                             refresh_token: refresh_token,
                             token_type: 'bearer')
    end

    def refreshed_token_info(refresh_token)
      dashboard_client = Settings.services[0].dashboard_client
      client = CF::UAA::TokenIssuer.new(
        Configuration.auth_server_url,
        dashboard_client.id,
        dashboard_client.secret,
        { token_target: Configuration.token_server_url }
      )
      client.refresh_token_grant(refresh_token)
    end
  end

  def initialize(token_info)
    @token_info = token_info
  end

  def auth_header
    token_info.auth_header
  end

  def access_token
    token_info.info[:access_token] || token_info.info["access_token"]
  end

  def refresh_token
    token_info.info[:refresh_token] || token_info.info["refresh_token"]
  end

  private

  attr_reader :token_info
end
