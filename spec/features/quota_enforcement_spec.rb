require 'spec_helper'
require Rails.root.join('app/queries/service_instance_usage_query')

describe 'Quota enforcement' do
  let(:instance_id_0) { SecureRandom.uuid }
  let(:binding_id_0) { SecureRandom.uuid }
  let(:max_storage_mb_0) { Settings.services[0].plans[0].max_storage_mb.to_i }

  let(:instance_id_1) { SecureRandom.uuid }
  let(:binding_id_1) { SecureRandom.uuid }
  let(:max_storage_mb_1) { Settings.services[0].plans[1].max_storage_mb.to_i }

  after do
    delete "/v2/service_instances/#{instance_id_0}/service_bindings/#{binding_id_0}"
    delete "/v2/service_instances/#{instance_id_0}"

    delete "/v2/service_instances/#{instance_id_1}/service_bindings/#{binding_id_1}"
    delete "/v2/service_instances/#{instance_id_1}"
  end

  specify 'User violates and recovers from quota limit' do
    put "/v2/service_instances/#{instance_id_0}", {plan_id: Settings.services[0].plans[0].id}
    put "/v2/service_instances/#{instance_id_0}/service_bindings/#{binding_id_0}"
    binding_0 = JSON.parse(response.body)
    credentials_0 = binding_0.fetch('credentials')

    put "/v2/service_instances/#{instance_id_1}", {plan_id: Settings.services[0].plans[1].id}
    put "/v2/service_instances/#{instance_id_1}/service_bindings/#{binding_id_1}"
    binding_1 = JSON.parse(response.body)
    credentials_1 = binding_1.fetch('credentials')

    client_0 = create_mysql_client(credentials_0)
    client_1 = create_mysql_client(credentials_1)
    overflow_database(client_0, max_storage_mb_0)
    overflow_database(client_1, max_storage_mb_1)
    recalculate_usage(instance_id_0)
    recalculate_usage(instance_id_1)

    enforce_quota

    verify_connection_terminated(client_0)
    verify_connection_terminated(client_1)

    client_0 = create_mysql_client(credentials_0)
    client_1 = create_mysql_client(credentials_1)
    verify_write_privileges_revoked(client_0)
    verify_write_privileges_revoked(client_1)
    prune_database(client_0)
    prune_database(client_1)
    recalculate_usage(instance_id_0)
    recalculate_usage(instance_id_1)

    enforce_quota

    verify_connection_terminated(client_0)
    verify_connection_terminated(client_1)

    client_0 = create_mysql_client(credentials_0)
    client_1 = create_mysql_client(credentials_1)
    verify_write_privileges_restored(client_0)
    verify_write_privileges_restored(client_1)
  end

  def create_mysql_client(config)
    Mysql2::Client.new(
      :host => config.fetch('hostname'),
      :port => config.fetch('port'),
      :database => config.fetch('name'),
      :username => config.fetch('username'),
      :password => config.fetch('password')
    )
  end

  def overflow_database(client, max_storage_mb)
    client.query('CREATE TABLE stuff (id INT PRIMARY KEY, data LONGTEXT) ENGINE=InnoDB')

    data = '1' * (1024 * 1024) # 1 MB

    max_storage_mb.times do |n|
      client.query("INSERT INTO stuff (id, data) VALUES (#{n}, '#{data}')")
    end
  end

  def prune_database(client)
    client.query('DELETE FROM stuff LIMIT 2')
  end

  def recalculate_usage(instance_id)
    # Getting Mysql to update statistics is a little tricky. With the right configuration settings,
    # Mysql will do it automatically. With the wrong settings, you may need to ANALYZE or OPTIMIZE.
    # For the tests we will run OPTIMIZE to ensure the settings update immediately.

    db_name = ServiceInstanceManager.database_name_from_service_instance_guid(instance_id)
    #ActiveRecord::Base.connection.execute("ANALYZE TABLE #{instance.database}.stuff")
    ActiveRecord::Base.connection.execute("OPTIMIZE TABLE #{db_name}.stuff")
  end

  def enforce_quota
    puts `rake quota:enforce`
  end

  def verify_connection_terminated(client)
    expect {
      client.query('SELECT 1')
    }.to raise_error(Mysql2::Error, /server has gone away/)
  end

  def verify_write_privileges_revoked(client)
    # see that insert/update/create privileges have been revoked
    expect {
      client.query("INSERT INTO stuff (id, data) VALUES (99999, 'This should fail.')")
    }.to raise_error(Mysql2::Error, /INSERT command denied/)

    expect {
      client.query("UPDATE stuff SET data = 'This should also fail.' WHERE id = 1")
    }.to raise_error(Mysql2::Error, /UPDATE command denied/)

    expect {
      client.query('CREATE TABLE more_stuff (id INT PRIMARY KEY)')
    }.to raise_error(Mysql2::Error, /CREATE command denied/)

    # see that read privileges have not been revoked
    client.query('SELECT COUNT(*) FROM stuff')
  end

  def verify_write_privileges_restored(client)
    client.query("INSERT INTO stuff (id, data) VALUES (99999, 'This should succeed.')")
    client.query("UPDATE stuff SET data = 'This should also succeed.' WHERE id = 99999")
  end
end
