module RequestHelpers
  extend ActiveSupport::Concern

  included do
    let(:default_env) do
      username = 'test'
      password = 'secret'

      {
        'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
      }
    end
    let(:env) { default_env }

    before do
      @__original_auth_token, ENV['AUTH_TOKEN'] = ENV['AUTH_TOKEN'], 'secret'
    end

    after do
      ENV['AUTH_TOKEN'], @__original_auth_token = @__original_auth_token, nil
    end
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
