require 'spec_helper'


def cleanup_mysql_user(username)
  ActiveRecord::Base.connection.execute("DROP USER #{username}")
rescue
end

def create_mysql_client(username, password)
  Mysql2::Client.new(
      :host     => AppSettings.database.host,
      :port     => AppSettings.database.port,
      :database => AppSettings.database.singleton_database,
      :username => username,
      :password => password
  )
end


describe 'POST /v2/service_bindings' do
  let(:instance_guid) { 'INSTANCE-1' }
  let(:binding_guid) { 'BINDING-1' }
  let(:password) { 'somepassword' }
  let(:username) { UserCreds.new(binding_guid).username }

  before do
    SecureRandom.stub(:hex).with(8).and_return(password)
    cleanup_mysql_user(username)

    put "/v2/service_instances/#{instance_guid}", {service_plan_id: 'PLAN-1'}, env
  end

  after do
    cleanup_mysql_user(username)
  end

  it 'creates a user and returns the new service binding' do
    ## Create the binding
    put "/v2/service_bindings/#{binding_guid}", {service_instance_id: instance_guid}, env

    expect(response.status).to eq(201)
    instance = JSON.parse(response.body)

    expect(instance.fetch('credentials')).to eq({
      'hostname' => 'localhost',
      'name' => 'test',
      'username' => username,
      'password' => password,
      'port' => 3306,
      'jdbcUrl' => "jdbc:mysql://#{username}:#{password}@localhost:3306/test",
      'uri' => "mysql://#{username}:#{password}@localhost:3306/test?reconnect=true",
    })

    ## Test the binding
    client = create_mysql_client(username, password)

    client.query("CREATE TABLE IF NOT EXISTS data_values ( id VARCHAR(20), data_value VARCHAR(20));")
    client.query("INSERT INTO data_values VALUES('123', '456');")
    found = client.query("SELECT id, data_value FROM data_values;").first
    expect(found.fetch('data_value')).to eq('456')

    ## Delete the binding
    delete "/v2/service_bindings/#{binding_guid}", {service_instance_id: instance_guid}, env
    expect(response.status).to eq(204)

    ## Test that the binding no longer works
    expect {
      create_mysql_client(username, password)
    }.to raise_error
  end
end
