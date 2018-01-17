require Rails.root.join('lib/service_instance_manager')

class DatabaseNotFoundError < StandardError; end
class ServiceBinding < BaseModel
  attr_accessor :id, :service_instance, :read_only

  def self.find_by_id(id)
    binding = new(id: id)

    begin
      connection.execute("SHOW GRANTS FOR '#{binding.username}'")
      binding
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message =~ /no such grant/
    end
  end


  def self.find_by_id_and_service_instance_guid(id, instance_guid)
    binding = new(id: id)

    begin
      grants = connection.select_values("SHOW GRANTS FOR '#{binding.username}'")

      database_name = ServiceInstanceManager.database_name_from_service_instance_guid(instance_guid)
      # Can we do this more elegantly, i.e., without checking for a
      # particular raw GRANT statement?

      if grants.any? { |grant| grant.match(Regexp.new("GRANT .* ON `#{database_name}`\\.\\* TO '#{binding.username}'@'%'")) }
        binding
      end
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message =~ /no such grant/
    end
  end

  def self.exists?(conditions)
    id = conditions.fetch(:id)
    instance_guid = conditions.fetch(:service_instance_guid)

    find_by_id_and_service_instance_guid(id, instance_guid).present?
  end

  def host
    connection_config.fetch('host')
  end

  def port
    connection_config.fetch('port')
  end

  def database_name
    ServiceInstanceManager.database_name_from_service_instance_guid(service_instance.guid)
  end

  def username
    Digest::MD5.base64digest(id).gsub(/[^a-zA-Z0-9]+/, '')[0...16]
  end

  def password
    @password ||= SecureRandom.base64(20).gsub(/[^a-zA-Z0-9]+/, '')[0...16]
  end

  def save
    unless Database.exists?(database_name)
      raise DatabaseNotFoundError.new("Service instance '#{service_instance.guid}' database does not exist")
    end

    begin
      connection.execute("CREATE USER '#{username}' IDENTIFIED BY '#{password}'")
    rescue => e
      raise e, e.message.gsub(password, 'redacted'), e.backtrace
    end

    update_connection_quota_for_user
    create_read_only_user if read_only
  end

  def destroy
    connection.execute("DROP USER '#{username}'")
    ReadOnlyUser.find_by_username(username).try(:destroy)
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message =~ /DROP USER failed/
  end

  def to_json(*)
    obj = {
      'credentials' => {
        'hostname' => host,
        'port' => port,
        'name' => database_name,
        'username' => username,
        'password' => password,
        'uri' => uri,
        'jdbcUrl' => jdbc_url
      }
    }

    if Settings['tls_ca_certificate']
      obj['credentials']['ca_certificate'] = Settings['tls_ca_certificate']
    end
    obj.to_json
  end

  def self.update_all_max_user_connections
    # We would like to update these users in bulk by updating mysql.user
    # directly, but Galera does not replicate this table. DDL statments such
    # as GRANT USAGE must be used instead to ensure replication.
    Catalog.plans.each do |plan|
      users = connection.select_values(get_all_users_with_plan(plan))
      users.each do |user|
        connection.execute(update_max_user_connection_for_user(user, plan))
      end
    end
  end

  private

  def update_connection_quota_for_user
    max_user_connections = Catalog.connection_quota_for_plan_guid(service_instance.plan_guid)

    privileges = read_only ? "SELECT" : "ALL PRIVILEGES"
    grant_sql = "GRANT #{privileges} ON `#{service_instance.db_name}`.* TO '#{username}'@'%'"
    grant_sql = grant_sql +  " WITH MAX_USER_CONNECTIONS #{max_user_connections}" if max_user_connections
    connection.execute(grant_sql)

    if !Settings.allow_table_locks
      revoke_sql = "REVOKE LOCK TABLES ON `#{service_instance.db_name}`.* FROM '#{username}'@'%'"
      connection.execute(revoke_sql)
    end
  end

  def create_read_only_user
    ReadOnlyUser.create(username: username, grantee: "'#{username}'@'%'")
  end

  def self.update_max_user_connection_for_user(user, plan)
<<-SQL
GRANT USAGE ON *.* TO '#{user}'@'%'
WITH MAX_USER_CONNECTIONS #{plan.max_user_connections}
SQL
  end

  def self.get_all_users_with_plan(plan)
<<-SQL
SELECT mysql.user.user
FROM service_instances
JOIN mysql.db ON service_instances.db_name=mysql.db.Db
JOIN mysql.user ON mysql.user.User=mysql.db.User
WHERE plan_guid='#{plan.id}' AND mysql.user.user NOT LIKE 'root'
SQL
  end

  def connection_config
    Rails.configuration.database_configuration[Rails.env]
  end

  def uri
    "mysql://#{username}:#{password}@#{host}:#{port}/#{database_name}?reconnect=true"
  end

  def ssl_arguments
    return unless Settings['tls_ca_certificate']
    mysql_connector_j_flag = 'enabledTLSProtocols=TLSv1.2'
    mariadb_connector_j_flag = 'enabledSslProtocolSuites=TLSv1.2'
    "&useSSL=true&#{mysql_connector_j_flag}&#{mariadb_connector_j_flag}"
  end

  def jdbc_url
    "jdbc:mysql://#{host}:#{port}/#{database_name}?user=#{username}&password=#{password}#{ssl_arguments}"
  end
end
