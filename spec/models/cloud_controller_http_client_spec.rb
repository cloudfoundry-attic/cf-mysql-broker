require 'spec_helper'

describe CloudControllerHttpClient do
  describe '#get' do
    let(:client) { CloudControllerHttpClient.new(auth_header) }
    let(:cc_url) { 'http://api.example.com/cc' }
    let(:auth_header) { 'a-correct-header' }
    let(:response_body) { '{"something": true}' }

    before do
      allow(Settings).to receive(:cc_api_uri).and_return(cc_url)

      stub_request(:get, %r(#{cc_url}/.*)).
        to_return(body: response_body)
    end

    it 'makes a request to the correct endpoint' do
      client.get("/path/to/endpoint")
      expect(
        a_request(:get, "#{cc_url}/path/to/endpoint").
          with(headers: { 'Authorization' => auth_header })
      ).to have_been_made
    end

    it 'returns the parsed response body' do
      expect(client.get("/path/to/endpoint")).to eq(JSON.parse(response_body))
    end

    context 'when the cc_url has a trailing slash' do
      let(:cc_url) { 'http://api.example.com/cc/' }

      before do
        stub_request(:get, %r(#{cc_url}.*)).
          to_return(body: response_body)
      end

      it 'constructs the request url appropriately' do
        client.get("/path/to/endpoint")
        expect(
          a_request(:get, "#{cc_url}path/to/endpoint")
        ).to have_been_made
      end
    end

    context 'when the CC uri uses https' do
      let(:cc_url) { 'https://api.example.com/cc' }

      it 'makes a request to the correct endpoint' do
        client.get("/path/to/endpoint")
        expect(
          a_request(:get, "#{cc_url}/path/to/endpoint").
            with(headers: { 'Authorization' => auth_header })
        ).to have_been_made
      end

      describe 'ssl cert verification' do
        let(:http) { double(:http) }
        let(:response) { double(:response, body: '{}') }

        before do
          allow(Net::HTTP).to receive(:new).and_return(http)
          allow(http).to receive(:use_ssl=)
          allow(http).to receive(:verify_mode=)
          allow(http).to receive(:request).and_return(response)
        end

        it 'sets use_ssl to true' do
          client.get('/a/path')
          expect(http).to have_received(:use_ssl=).with(true)
        end

        context 'when skip_ssl_validation is false' do
          before do
            allow(Settings).to receive(:skip_ssl_validation).and_return(false)
          end

          it 'verifies the ssl cert' do
            client.get('/a/path')
            expect(http).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
          end
        end

        context 'when skip_ssl_validation is true' do
          before do
            allow(Settings).to receive(:skip_ssl_validation).and_return(true)
          end

          it 'does not verify the ssl cert' do
            client.get('/a/path')
            expect(http).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
          end
        end
      end
    end
  end
end
