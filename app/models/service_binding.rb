require Rails.root.join('lib/service_instance_manager')

class ServiceBinding < BaseModel
  attr_accessor :id, :service_instance

  # Returns a given binding, if the MySQL user exists.
  #
  # NOTE: This method cannot currently check for the true existence of
  # the binding. A binding is the association of a MySQL user with a
  # database. We use the binding id to identify a user and the instance
  # id to identify a database. As such, we really need both ids to be
  # sure the binding exists. This problem is resolvable by persisting
  # both ids and their relationship in a separate management database.

  def self.find_by_id(id)
    binding = new(id: id)

    begin
      connection.execute("SHOW GRANTS FOR #{connection.quote(binding.username)}")
      binding
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message =~ /no such grant/
    end
  end

  # Returns a given binding, if it exists.
  #
  # NOTE: This method is only necessary because of the current
  # shortcomings of +find_by_id+. And because it requires both
  # the binding id and the instance guid, it cannot currently be
  # used by the binding controller.

  def self.find_by_id_and_service_instance_guid(id, instance_guid)
    binding = new(id: id)

    begin
      grants = connection.select_values("SHOW GRANTS FOR #{connection.quote(binding.username)}")

      database_name = ServiceInstanceManager.database_name_from_service_instance_guid(instance_guid)
      # Can we do this more elegantly, i.e., without checking for a
      # particular raw GRANT statement?
      if grants.include?("GRANT ALL PRIVILEGES ON #{connection.quote_table_name(database_name)}.* TO #{connection.quote(binding.username)}@'%'")
        binding
      end
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message =~ /no such grant/
    end
  end

  # Checks to see if the given binding exists.
  #
  # NOTE: This method uses +find_by_id_and_service_instance_guid+ to
  # verify true existence, and thus cannot currently be used by the
  # binding controller.

  def self.exists?(conditions)
    id = conditions.fetch(:id)
    instance_guid = conditions.fetch(:service_instance_guid)

    find_by_id_and_service_instance_guid(id, instance_guid).present?
  end

  def self.count
    cnt = connection.execute("SELECT COUNT(DISTINCT USER) FROM mysql.user").first[0]
    cnt ? cnt : 0
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
    raise "Service instance '#{service_instance.guid}' database does not exist" unless Database.exists?(database_name)

    connection.execute("CREATE USER #{connection.quote(username)} IDENTIFIED BY #{connection.quote(password)}")

    ServiceBinding.update_connection_quota_for_user(username, service_instance)
  end

  def self.update_connection_quota_for_user(username, service_instance)
    max_user_connections = Catalog.connection_quota_for_plan_guid(service_instance.plan_guid)
    grant_sql = "GRANT ALL PRIVILEGES ON #{connection.quote_table_name(service_instance.db_name)}.* TO #{connection.quote(username)}@'%'"
    grant_sql = grant_sql +  " WITH MAX_USER_CONNECTIONS #{max_user_connections}" if max_user_connections
    connection.execute(grant_sql)
    # Some MySQL installations, e.g., Travis, seem to need privileges
    # to be flushed even when using the appropriate account management
    # statements, despite what the MySQL documentation says:
    # http://dev.mysql.com/doc/refman/5.6/en/privilege-changes.html
    connection.execute('FLUSH PRIVILEGES')
  end

  def destroy
    begin
      connection.execute("DROP USER #{connection.quote(username)}")
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message =~ /DROP USER failed/
    else
      # Some MySQL installations, e.g., Travis, seem to need privileges
      # to be flushed even when using the appropriate account management
      # statements, despite what the MySQL documentation says:
      # http://dev.mysql.com/doc/refman/5.6/en/privilege-changes.html
      connection.execute('FLUSH PRIVILEGES')
    end
  end

  def to_json(*)
    {
      'credentials' => {
        'hostname' => host,
        'port' => port,
        'name' => database_name,
        'username' => username,
        'password' => password,
        'uri' => uri,
        'jdbcUrl' => jdbc_url
      }
    }.to_json
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
    connection.execute('FLUSH PRIVILEGES')
  end

  private

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

  def jdbc_url
    "jdbc:mysql://#{host}:#{port}/#{database_name}?user=#{username}&password=#{password}"
  end
end
