unless Rails.env.assets?
  OmniAuth.config.failure_raise_out_environments = []
  OmniAuth.config.path_prefix = '/manage/auth'

  client = Settings.services[0].dashboard_client

  Rails.application.config.middleware.use OmniAuth::Builder do
    unless (Rails.env.travis_test? || Rails.env.test? || Rails.env.development?)
      provider :cloudfoundry, client.id, client.secret, {
        auth_server_url: Configuration.auth_server_url,
        token_server_url: Configuration.token_server_url,
        scope: %w(cloud_controller_service_permissions.read openid)
      }
    end
  end
end
