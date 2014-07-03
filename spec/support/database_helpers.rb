module DatabaseHelpers
  def create_mysql_client(config)
    Mysql2::Client.new(
        :host => config.fetch('hostname'),
        :port => config.fetch('port'),
        :database => config.fetch('name'),
        :username => config.fetch('username'),
        :password => config.fetch('password')
    )
  end

  def create_table_and_write_data(client, max_storage_mb)
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

RSpec.configure do |config|
  config.include DatabaseHelpers, :example_group => { :file_path => %r(spec/features) }
end
