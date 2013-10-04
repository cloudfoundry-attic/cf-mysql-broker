class ServiceBinding < BaseModel
  attr_accessor :id, :service_instance

  def self.find_by_id(id)
    binding = new(id: id)

    begin
      connection.select_values("SHOW GRANTS FOR '#{binding.username}'")
      binding
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message =~ /no such grant/
    end
  end

  def username
    Digest::MD5.base64digest(id).gsub(/[^a-zA-Z0-9]+/, '')[0...16]
  end

  def save
    connection.execute("GRANT ALL PRIVILEGES ON `#{database}`.* TO '#{username}'@'%' IDENTIFIED BY '#{password}'")

    # Some MySQL installations, e.g., Travis, seem to need privileges
    # to be flushed even when using the appropriate account management
    # statements, despite what the MySQL documentation says:
    # http://dev.mysql.com/doc/refman/5.6/en/privilege-changes.html
    connection.execute('FLUSH PRIVILEGES')
  end

  def destroy
    begin
      connection.execute("DROP USER '#{username}'")

      # Some MySQL installations, e.g., Travis, seem to need privileges
      # to be flushed even when using the appropriate account management
      # statements, despite what the MySQL documentation says:
      # http://dev.mysql.com/doc/refman/5.6/en/privilege-changes.html
      connection.execute('FLUSH PRIVILEGES')
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message =~ /DROP USER failed/
    end
  end

  def to_json(*)
    {
      'credentials' => {
        'hostname' => host,
        'port' => port,
        'name' => database,
        'username' => username,
        'password' => password,
        'uri' => uri,
        'jdbcUrl' => jdbc_url
      }
    }.to_json
  end

  private

  def connection_config
    Rails.configuration.database_configuration[Rails.env]
  end

  def host
    connection_config.fetch('host')
  end

  def port
    connection_config.fetch('port')
  end

  def database
    service_instance.database
  end

  def password
    @password ||= SecureRandom.hex(8)
  end

  def uri
    "mysql://#{username}:#{password}@#{host}:#{port}/#{database}?reconnect=true"
  end

  def jdbc_url
    "jdbc:mysql://#{username}:#{password}@#{host}:#{port}/#{database}"
  end
end
