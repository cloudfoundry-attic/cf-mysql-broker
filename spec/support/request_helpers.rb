module RequestHelpers
  extend ActiveSupport::Concern

  included do
    let(:default_env) do
      username = 'test'
      password = Settings.auth_token

      {
        'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
      }
    end
    let(:env) { default_env }
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
