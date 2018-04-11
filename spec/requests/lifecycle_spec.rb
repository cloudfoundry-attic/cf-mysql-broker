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
    :host => Rails.configuration.database_configuration[Rails.env].fetch('host'),
    :port => Rails.configuration.database_configuration[Rails.env].fetch('port'),
    :database => database,
    :username => username,
    :password => password
  )
end

describe 'the service lifecycle' do
  let(:instance_id) {'instance-1'}
  let(:dbname) {'cf_instance_1'}

  let(:binding_id) {'binding-1'}
  let(:password) {'somepassword'}
  let(:username) {ServiceBinding.new(id: binding_id).username}
  let(:headers) {{"CONTENT_TYPE" => "application/json"}}

  before do
    cleanup_mysql_user(username)
    cleanup_mysql_database(dbname)
    allow(Settings).to receive(:allow_table_locks).and_return(true)
  end

  after do
    cleanup_mysql_user(username)
    cleanup_mysql_database(dbname)
  end

  describe 'bindings' do
    before do
      allow(SecureRandom).to receive(:base64).and_return(password, 'notthepassword')

      ##
      ## Provision the instance
      ##
      put "/v2/service_instances/#{instance_id}", {plan_id: '2451fa22-df16-4c10-ba6e-1f682d3dcdc9'}

      expect(response.status).to eq(201)
      expect(response.body).to eq("{\"dashboard_url\":\"http://p-mysql.bosh-lite.com/manage/instances/#{instance_id}\"}")
    end

    after do
      ##
      ## Unbind
      ##
      delete "/v2/service_instances/#{instance_id}/service_bindings/#{binding_id}"
      expect(response.status).to eq(200)
      expect(response.body).to eq('{}')

      ##
      ## Test that the binding no longer works
      ##
      expect {
        create_mysql_client(username, password, dbname)
      }.to raise_error(Mysql2::Error)

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
      expect(response.status).to eq(200)
      expect(response.body).to eq('{}')

      ##
      ## Test that the database no longer exists
      ##
      found = client.query("SHOW DATABASES LIKE '#{dbname}'")
      expect(found.count).to eq(0)
    end

    describe 'read/write binding' do
      it 'provisions, binds, unbinds, deprovisions' do
        ##
        ## Bind with incorrect arbitrary parameters
        ##
        put "/v2/service_instances/#{instance_id}/service_bindings/#{binding_id}",
          JSON.dump({"parameters" => {"read-oooonly" => true}}),
          headers.merge(env)

        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to eq({
          "error" => "Error creating service binding",
          "description" => "Invalid arbitrary parameter syntax. Please check the documentation for supported arbitrary parameters.",
        })

        ##
        ## Bind with invalid value for read-only parameter
        ##
        put "/v2/service_instances/#{instance_id}/service_bindings/#{binding_id}",
          JSON.dump({"parameters" => {"read-only" => "tomato"}}),
          headers.merge(env)

        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to eq({
          "error" => "Error creating service binding",
          "description" => "Invalid arbitrary parameter syntax. Please check the documentation for supported arbitrary parameters.",
        })

        ##
        ## Bind
        ##
        put "/v2/service_instances/#{instance_id}/service_bindings/#{binding_id}"

        expect(response.status).to eq(201)
        instance = JSON.parse(response.body)

        expect(instance.fetch('credentials')).to eq({
          'hostname' => 'localhost',
          'name' => dbname,
          'username' => username,
          'password' => password,
          'port' => 3306,
          'jdbcUrl' => "jdbc:mysql://localhost:3306/#{dbname}?user=#{username}&password=#{password}",
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
      end
    end

    describe 'read-only bindings' do
      it 'provisions, binds, unbinds, deprovisions' do
        ##
        ## Make a read-only binding
        ##
        put "/v2/service_instances/#{instance_id}/service_bindings/#{binding_id}",
          JSON.dump({"parameters" => {"read-only" => true}}),
          headers.merge(env)

        expect(response.status).to eq(201)
        instance = JSON.parse(response.body)

        expect(instance.fetch('credentials')).to eq({
          'hostname' => 'localhost',
          'name' => dbname,
          'username' => username,
          'password' => password,
          'port' => 3306,
          'jdbcUrl' => "jdbc:mysql://localhost:3306/#{dbname}?user=#{username}&password=#{password}",
          'uri' => "mysql://#{username}:#{password}@localhost:3306/#{dbname}?reconnect=true",
        })

        ##
        ## Verify that the binding has read access
        ##
        client = create_mysql_client(username, password, dbname)
        found = client.query("SHOW DATABASES LIKE '#{dbname}'")
        expect(found.count).to eq(1)

        ##
        ## Verify that the binding does not have write access
        ##
        expect {
          client.query("CREATE TABLE IF NOT EXISTS data_values (id VARCHAR(20), data_value VARCHAR(20));")
        }.to raise_error(Mysql2::Error)
      end
    end
  end
end
