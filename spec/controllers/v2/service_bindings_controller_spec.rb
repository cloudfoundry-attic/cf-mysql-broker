require 'spec_helper'

describe V2::ServiceBindingsController do
  before { authenticate }

  describe "#update" do
    let(:admin_user) { 'root' }
    let(:admin_password) { 'admin_password' }
    let(:singleton_database_name) { 'mydb' }
    let(:database_ip) { '10.10.1.1' }
    let(:database_port) { '3306' }

    before do
      authenticate
      allow(AppSettings).to receive(:database).and_return(
                                double(
                                    :admin_user => admin_user,
                                    :admin_password => admin_password,
                                    :singleton_database => singleton_database_name,
                                    :ip => database_ip,
                                    :port => database_port
                                )
                            )
    end

    it "responds with the root credentials from the configuration" do
      put :update, id: 123

      expect(response.status).to eq(201)
      binding = JSON.parse(response.body)

      expect(binding['credentials']).to eq(
                                            "hostname" => database_ip,
                                            "name"     => singleton_database_name,
                                            "username" => admin_user,
                                            "password" => admin_password,
                                            "port"     => database_port,

                                            "jdbcUrl"  => "jdbc:mysql://#{admin_user}:#{admin_password}@#{database_ip}:#{database_port}/#{singleton_database_name}",
                                            "uri"      => "mysql://#{admin_user}:#{admin_password}@#{database_ip}:#{database_port}/#{singleton_database_name}?reconnect=true",
                                        )
    end
  end

  describe '#destroy' do
    it 'succeeds with 204' do
      delete :destroy, id: '42'

      expect(response.status).to eq(204)
    end
  end
end
