require 'spec_helper'

# Provisions, binds, unbinds, deprovisions a service

def cleanup_mysql_user(username)
  ActiveRecord::Base.connection.execute("DROP USER #{username}")
rescue
end
def cleanup_mysql_database(dbname)
  ActiveRecord::Base.connection.execute("DROP DATABASE #{dbname}")
rescue
end

def create_mysql_client(username=Rails.configuration.database_configuration[Rails.env].fetch('username'),
                        password=Rails.configuration.database_configuration[Rails.env].fetch('password'),
                        database='mysql')
  Mysql2::Client.new(
      :host     => Rails.configuration.database_configuration[Rails.env].fetch('host'),
      :port     => Rails.configuration.database_configuration[Rails.env].fetch('port'),
      :database => database,
      :username => username,
      :password => password
  )
end


describe 'the service lifecycle' do
  let(:instance_id) { 'instance-1' }
  let(:dbname) { ServiceInstance.new(id: instance_id).database }

  let(:binding_id) { 'binding-1' }
  let(:password) { 'somepassword' }
  let(:username) { ServiceBinding.new(id: binding_id).username }

  before do
    SecureRandom.stub(:hex).with(8).and_return(password, 'not-the-password')
    cleanup_mysql_user(username)
    cleanup_mysql_database(dbname)
  end

  after do
    cleanup_mysql_user(username)
    cleanup_mysql_database(dbname)
  end

  it 'provisions, binds, unbinds, deprovisions' do
    ##
    ## Provision the instance
    ##
    put "/v2/service_instances/#{instance_id}", {service_plan_id: 'PLAN-1'}

    expect(response.status).to eq(201)
    instance = JSON.parse(response.body)

    expect(instance.fetch('dashboard_url')).to eq('http://fake.dashboard.url')

    ##
    ## Bind
    ##
    put "/v2/service_bindings/#{binding_id}", {service_instance_id: instance_id}

    expect(response.status).to eq(201)
    instance = JSON.parse(response.body)

    expect(instance.fetch('credentials')).to eq({
      'hostname' => 'localhost',
      'name' => dbname,
      'username' => username,
      'password' => password,
      'port' => 3306,
      'jdbcUrl' => "jdbc:mysql://#{username}:#{password}@localhost:3306/#{dbname}",
      'uri' => "mysql://#{username}:#{password}@localhost:3306/#{dbname}?reconnect=true",
    })

    ##
    ## Test the binding
    ##
    client = create_mysql_client(username, password, dbname)

    client.query("CREATE TABLE IF NOT EXISTS data_values (id VARCHAR(20), data_value VARCHAR(20));")
    client.query("INSERT INTO data_values VALUES('123', '456');")
    found = client.query("SELECT id, data_value FROM data_values;").first
    expect(found.fetch('data_value')).to eq('456')

    ##
    ## Unbind
    ##
    delete "/v2/service_bindings/#{binding_id}"
    expect(response.status).to eq(204)

    ##
    ## Test that the binding no longer works
    ##
    expect {
      create_mysql_client(username, password, dbname)
    }.to raise_error

    ##
    ## Test that we have purged any data associated with the user
    ##
    client = create_mysql_client()
    found = client.query("SELECT * FROM mysql.db WHERE User = '#{username}';")
    expect(found.count).to eq(0)
    found = client.query("SELECT * FROM mysql.user WHERE User = '#{username}';")
    expect(found.count).to eq(0)

    ##
    ## Deprovision
    ##
    delete "/v2/service_instances/#{instance_id}"
    expect(response.status).to eq(204)

    ##
    ## Test that the database no longer exists
    ##
    found = client.query("SHOW DATABASES LIKE '#{dbname}'")
    expect(found.count).to eq(0)
  end
end
