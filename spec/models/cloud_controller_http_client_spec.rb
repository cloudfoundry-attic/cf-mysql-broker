require 'spec_helper'

describe CloudControllerHttpClient do
  describe '#get' do
    let(:client) { CloudControllerHttpClient.new(cc_url, auth_header) }
    let(:cc_url) { 'http://api.example.com/cc' }
    let(:auth_header) { 'a-correct-header' }
    let(:response_body) { '{"something": true}' }

    before do
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
    end
  end
end
