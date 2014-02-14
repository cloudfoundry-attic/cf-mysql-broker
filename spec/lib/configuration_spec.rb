require 'spec_helper'

describe Configuration do

  before do
    Configuration.clear
    stub_request(:any, "#{Settings.cc_api_uri}/info").
      to_return(body: JSON.generate({
        name: 'vcap',
        build: '2222',
        support: 'http://support.cloudfoundry.com',
        version: 2,
        description: 'Cloud Foundry sponsored by Pivotal',
        authorization_endpoint: 'http://login.10.244.0.34.xip.io',
        token_endpoint: 'https://uaa.10.244.0.34.xip.io',
        allow_debug: true
      }))
  end

  describe '#auth_server_url' do
    it 'uses the cc_api_uri to get the uri for the auth server' do
      expect(Configuration.auth_server_url).to eql('http://login.10.244.0.34.xip.io')
      a_request(:get, "#{Settings.cc_api_uri}/info").should have_been_made
    end
  end

  describe '#token_server_url' do
    it 'uses the cc_api_uri to get the url for the token server' do
      expect(Configuration.token_server_url).to eql('https://uaa.10.244.0.34.xip.io')
      a_request(:get, "#{Settings.cc_api_uri}/info").should have_been_made
    end
  end

end
