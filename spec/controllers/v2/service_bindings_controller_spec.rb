require 'spec_helper'

describe V2::ServiceBindingsController do
  before { authenticate }

  describe '#update' do
    let(:creds) do
      {
          jdbcUrl: "jdbc:mysql://testuser:testpassword@testdb.csvbuoabzxev.us-east-1.rds.amazonaws.com:3306/testdb",
          uri: "mysql://testuser:testpassword@testdb.csvbuoabzxev.us-east-1.rds.amazonaws.com:3306/testdb?reconnect=true",
          name: "fun",
          hostname: "testdb.csvbuoabzxev.us-east-1.rds.amazonaws.com",
          port: "3306",
          username: "testuser",
          password: "testpassword"
      }.to_json
    end

    it 'sends back credentials' do
      put :update, id: '42'

      expect(response.status).to eq(201)
      instance = JSON.parse(response.body)

      expect(instance['credentials']).to eq(creds)
    end
  end

  describe '#destroy' do
    it 'succeeds with 204' do
      delete :destroy, id: '42'

      expect(response.status).to eq(204)
    end
  end
end
