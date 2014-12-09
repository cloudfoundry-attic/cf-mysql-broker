module MysqlHelpers
  def create_mysql_client(binding)
    Mysql2::Client.new(
      :host     => binding.host,
      :port     => binding.port,
      :database => binding.database_name,
      :username => binding.username,
      :password => binding.password
    )
  end

  def create_root_mysql_client
    config = Rails.configuration.database_configuration[Rails.env]

    Mysql2::Client.new(
      :host     => binding1.host,
      :port     => binding1.port,
      :database => binding1.database_name,
      :username => config.fetch('username'),
      :password => config.fetch('password')
    )
  end

  def overflow_database(client, max_mb)
    client.query('CREATE TABLE stuff (id INT PRIMARY KEY, data LONGTEXT) ENGINE=InnoDB')
    client.query('CREATE TABLE stuff2 (id INT PRIMARY KEY, data LONGTEXT) ENGINE=InnoDB')

    data = '1' * (1024 * 512) # 0.5 MB
    data = client.escape(data)

    max_mb.times do |n|
      client.query("INSERT INTO stuff (id, data) VALUES (#{n}, '#{data}')")
      client.query("INSERT INTO stuff2 (id, data) VALUES (#{n}, '#{data}')")
    end
  end

  def prune_database(client)
    client.query('DELETE FROM stuff')
    client.query('DELETE FROM stuff2')
  end

# Force MySQL to immediately recalculate table usage. Normally
# there can be a 5+ second delay. Forcing the calculation here
# allows us to immediately test the quota enforcer, as this will
# ensure it has the latest usage stats with which to make its
# enforcement decisions.
  def recalculate_usage(binding)
    # For some reason, ANALYZE TABLE doesn't update statistics in Travis' environment
    ActiveRecord::Base.connection.execute("OPTIMIZE TABLE #{binding.database_name}.stuff")
    ActiveRecord::Base.connection.execute("OPTIMIZE TABLE #{binding.database_name}.stuff2")
  end

  def verify_write_privileges_allowed(binding)
    client = create_mysql_client(binding)
    expect {
      client.query("INSERT INTO stuff (id, data) VALUES (99999, 'This should succeed.')")
    }.to_not raise_error

    expect {
      client.query("UPDATE stuff SET data = 'This should also succeed.' WHERE id = 99999")
    }.to_not raise_error

    expect {
      client.query('CREATE TABLE more_stuff (id INT PRIMARY KEY)')
    }.to_not raise_error

    expect {
      client.query('SELECT COUNT(*) FROM stuff')
    }.to_not raise_error

    expect {
      client.query('DELETE FROM stuff WHERE id = 99999')
    }.to_not raise_error
  end

  def verify_write_privileges_revoked_select_and_delete_allowed(binding)
    client = create_mysql_client(binding)
    expect {
      client.query("INSERT INTO stuff (id, data) VALUES (99999, 'This should fail.')")
    }.to raise_error(Mysql2::Error, /INSERT command denied/)

    expect {
      client.query("UPDATE stuff SET data = 'This should also fail.' WHERE id = 1")
    }.to raise_error(Mysql2::Error, /UPDATE command denied/)

    expect {
      client.query('CREATE TABLE more_stuff (id INT PRIMARY KEY)')
    }.to raise_error(Mysql2::Error, /CREATE command denied/)

    expect {
      client.query('SELECT COUNT(*) FROM stuff')
    }.to_not raise_error

    expect {
      client.query('DELETE FROM stuff WHERE id = 1')
    }.to_not raise_error
  end

  def generate_clients_and_connections_for_all_bindings
    clients = bindings.map do |binding|
      create_mysql_client(binding)
    end

    clients.each { |client| client.query('SELECT 1') }

    clients
  end

  def verify_connection_not_killed(client)
    expect {
      client.query('SELECT 1')
    }.to_not raise_error
  end

  def verify_connection_killed(client)
    expect {
      client.query('SELECT 1')
    }.to raise_error(Mysql2::Error, /server has gone away/)
  end

  def verify_root_connections_are_not_killed
    client = create_root_mysql_client
    client.query('SELECT 1')

    Quota::Enforcer.enforce!

    expect {
      client.query('SELECT 1')
    }.to_not raise_error
  end

  def max_user_connection_quota(binding)
    client = create_root_mysql_client
    grants = client.query("SHOW GRANTS FOR #{binding.username}")
    # The grants come in a well defined format, which we hackily parse here
    # this assumes reasonable things like that you only have one db per binding
    grants.each do |g|
      return g.values[0].split.last.to_i
    end
  end
end
