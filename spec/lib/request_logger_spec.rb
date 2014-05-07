require 'spec_helper'

describe RequestLogger do
  describe "#log_request" do
    let(:fake_rails_logger) { double(:fake_rails_logger) }
    let(:request_logger) { described_class.new(fake_rails_logger) }

    let(:headers) {
      {
        "CONTENT_TYPE" => 'application/json',
        "HTTP_AUTHORIZATION" => 'basic: some-auth-token',
        "THIS_KEY_SHOULD_NOT_BE_LOGGED" => 'unknown'
      }
    }

    it 'logs the request headers and body' do
      expect(fake_rails_logger).to receive(:info) do |log_message|
        json_log_message = log_message.sub(/^Request:\s+/, "")

        request_info = JSON.parse(json_log_message)
        expect(request_info['body']).to eq "request body"
        expect(request_info['headers']["CONTENT_TYPE"]).to eq "application/json"
      end

      request_logger.log_headers_and_body(headers, "request body")
    end

    it 'filters out sensitive data headers' do
      expect(fake_rails_logger).to receive(:info) do |log_message|
        json_log_message = log_message.sub(/^Request:\s+/, "")

        request_info = JSON.parse(json_log_message)
        expect(request_info['headers']["HTTP_AUTHORIZATION"]).not_to match "some-auth-token"
      end

      request_logger.log_headers_and_body(headers, "request body")
    end

    it 'does not log unknown headers' do
      expect(fake_rails_logger).to receive(:info) do |log_message|
        json_log_message = log_message.sub(/^Request:\s+/, "")

        request_info = JSON.parse(json_log_message)
        expect(request_info['headers']).not_to have_key("THIS_KEY_SHOULD_NOT_BE_LOGGED")
      end

      request_logger.log_headers_and_body(headers, "request body")
    end
  end
end
