shared_examples_for 'a controller action that logs its request headers and body' do
  it 'logs the request' do
    received_log_messages = []
    Rails.logger.stub(:info) do |log_message|
      match_data = /^Request:\s+(.*)/.match(log_message)
      if match_data
        json_request_info = match_data[1]

        request_info = JSON.parse(json_request_info)
        received_log_messages << request_info if request_info.has_key?('headers') && request_info.has_key?('body')
      end
    end

    make_request

    expect(received_log_messages.length).to eq 1
    message = received_log_messages.first

    expect(message['body']).to be_empty
    expect(message['headers']).not_to be_empty
  end
end

shared_examples_for 'a controller action that requires basic auth' do
  context 'when the basic-auth username is incorrect' do
    before do
      set_basic_auth('wrong_username', Settings.auth_password)
    end

    it 'responds with a 401' do
      make_request

      expect(response.status).to eq(401)
    end
  end
end

module ControllerHelpers
  extend ActiveSupport::Concern

  def authenticate
    set_basic_auth(Settings.auth_username, Settings.auth_password)
  end

  def set_basic_auth(username, password)
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
  end

  def db
    ActiveRecord::Base.connection
  end
end

RSpec.configure do |config|
  config.include ControllerHelpers, type: :controller
end
