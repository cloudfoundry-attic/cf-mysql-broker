require 'spec_helper'

describe RequestResponseLogger do
  describe "#log_headers_and_body" do
    let(:fake_rails_logger) { double(:fake_rails_logger) }
    let(:request_response_logger) { described_class.new("Message:", fake_rails_logger) }

    let(:headers) {
      {
        "CONTENT_TYPE" => 'application/json',
        "HTTP_AUTHORIZATION" => 'basic: some-auth-token',
        "THIS_KEY_SHOULD_NOT_BE_LOGGED" => 'unknown'
      }
    }

    it 'logs the request headers and body' do
      expect(fake_rails_logger).to receive(:info) do |log_message|
        json_log_message = log_message.sub(/^\s+Message:\s+/, "")

        request_info = JSON.parse(json_log_message)
        expect(request_info['body']).to eq "body"
        expect(request_info['headers']["CONTENT_TYPE"]).to eq "application/json"
      end

      request_response_logger.log_headers_and_body(headers, "body")
    end

    it 'filters out sensitive data headers' do
      expect(fake_rails_logger).to receive(:info) do |log_message|
        json_log_message = log_message.sub(/^\s+Message:\s+/, "")

        request_info = JSON.parse(json_log_message)
        expect(request_info['headers']["HTTP_AUTHORIZATION"]).not_to match "some-auth-token"
      end

      request_response_logger.log_headers_and_body(headers, "body")
    end

    it 'does not log unknown headers' do
      expect(fake_rails_logger).to receive(:info) do |log_message|
        json_log_message = log_message.sub(/^\s+Message:\s+/, "")

        request_info = JSON.parse(json_log_message)
        expect(request_info['headers']).not_to have_key("THIS_KEY_SHOULD_NOT_BE_LOGGED")
      end

      request_response_logger.log_headers_and_body(headers, "body")
    end

    context 'when log_all_headers is true' do
      it 'filters out sensitive data headers' do
        expect(fake_rails_logger).to receive(:info) do |log_message|
          json_log_message = log_message.sub(/^\s+Message:\s+/, "")

          request_info = JSON.parse(json_log_message)
          expect(request_info['headers']["HTTP_AUTHORIZATION"]).not_to match "some-auth-token"
        end

        request_response_logger.log_headers_and_body(headers, "body", true)
      end

      it 'logs unknown headers' do
        expect(fake_rails_logger).to receive(:info) do |log_message|
          json_log_message = log_message.sub(/^\s+Message:\s+/, "")

          request_info = JSON.parse(json_log_message)
          expect(request_info['headers']).to have_key("THIS_KEY_SHOULD_NOT_BE_LOGGED")
        end

        request_response_logger.log_headers_and_body(headers, "body", true)
      end
    end
  end
end
