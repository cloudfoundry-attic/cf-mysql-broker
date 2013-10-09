require 'spec_helper'

describe 'Quota enforcement' do
  let(:instance_id) { SecureRandom.uuid }
  let(:binding_id) { SecureRandom.uuid }

  before do
    put "/v2/service_instances/#{instance_id}", {service_plan_id: 'PLAN-1'}
    put "/v2/service_bindings/#{binding_id}", {service_instance_id: instance_id}
  end

  after do
    delete "/v2/service_bindings/#{binding_id}"
    delete "/v2/service_instances/#{instance_id}"
  end

  specify 'User violates and recovers from quota limit' do
    binding = JSON.parse(response.body)
    credentials = binding.fetch('credentials')

    client1 = create_mysql_client(credentials)
    overflow_database(client1)
    enforce_quota
    verify_connection_terminated(client1)

    client2 = create_mysql_client(credentials)
    verify_write_privileges_revoked(client2)
    prune_database(client2)
    enforce_quota
    verify_connection_terminated(client2)

    client3 = create_mysql_client(credentials)
    verify_write_privileges_restored(client3)
  end

  def create_mysql_client(config)
    Mysql2::Client.new(
      :host     => config.fetch('hostname'),
      :port     => config.fetch('port'),
      :database => config.fetch('name'),
      :username => config.fetch('username'),
      :password => config.fetch('password')
    )
  end

  def overflow_database(client)
    client.query('CREATE TABLE stuff (id INT PRIMARY KEY, data LONGTEXT) ENGINE=InnoDB')

    data = '1' * (1024 * 1024) # 1 MB
    data = client.escape(data)

    10.times do |n|
      client.query("INSERT INTO stuff (id, data) VALUES (#{n}, '#{data}')")
    end

    recalculate_usage
  end

  def prune_database(client)
    client.query('DELETE FROM stuff WHERE id = 9')

    recalculate_usage
  end

  def recalculate_usage
    instance = ServiceInstance.new(id: instance_id)
    # For some reason, ANALYZE TABLE doesn't update statistics in Travis' environment
    ActiveRecord::Base.connection.execute("OPTIMIZE TABLE #{instance.database}.stuff")
  end

  def enforce_quota
    `rake quota:enforce`
  end

  def verify_connection_terminated(client)
    expect {
      client.query('SELECT 1')
    }.to raise_error(Mysql2::Error, /server has gone away/)
  end

  def verify_write_privileges_revoked(client)
    # see that insert/update/create privileges have been revoked
    expect {
      client.query("INSERT INTO stuff (id, data) VALUES (10, 'This should fail.')")
    }.to raise_error(Mysql2::Error, /INSERT command denied/)

    expect {
      client.query("UPDATE stuff SET data = 'This should also fail.' WHERE id = 9")
    }.to raise_error(Mysql2::Error, /UPDATE command denied/)

    expect {
      client.query('CREATE TABLE more_stuff (id INT PRIMARY KEY)')
    }.to raise_error(Mysql2::Error, /CREATE command denied/)

    # see that read privileges have not been revoked
    client.query('SELECT COUNT(*) FROM stuff')
  end

  def verify_write_privileges_restored(client)
    client.query("INSERT INTO stuff (id, data) VALUES (10, 'This should succeed.')")
    client.query("UPDATE stuff SET data = 'This should also succeed.' WHERE id = 10")
  end
end
