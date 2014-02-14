require 'spec_helper'

class Settings
  def dashboard_client
    OpenStruct.new(id: '<client id>', secret: '<client secret>')
  end
end

describe AccessTokenHandler do
  describe '#auth_header' do
    let(:access_token) { 'my_access_token' }
    let(:refresh_token) { 'my_refresh_token' }

    let(:handler) { AccessTokenHandler.new(access_token, refresh_token) }

    context 'when the access token is not expired' do
      before do
        CF::UAA::TokenCoder.stub(:decode).and_return(expires_at: 1.minute.from_now.to_i)
      end

      it 'returns a token that is encoded and can be used in a header' do
        expect(handler.auth_header).to eql('bearer my_access_token')
      end
    end

    context 'when the access token is expired' do
      before do
        CF::UAA::TokenCoder.stub(:decode).and_return(expires_at: 1.minute.ago.to_i)

        Configuration.stub(:auth_server_url) { 'http://login.example.com' }
        Configuration.stub(:token_server_url) { 'http://uaa.example.com' }
        token_info = CF::UAA::TokenInfo.new(access_token: 'new_access_token', token_type: 'bearer')
        token_issuer = double(CF::UAA::TokenIssuer, refresh_token_grant: token_info)
        CF::UAA::TokenIssuer.should_receive(:new).with('http://login.example.com',
                                                       '<client id>',
                                                       '<client secret>',
                                                       { token_target: 'http://uaa.example.com' }).
                                                       and_return(token_issuer)
      end

      it 'uses the refresh token to get a new access token' do
        expect(handler.auth_header).to eql('bearer new_access_token')
      end
    end
  end
end
