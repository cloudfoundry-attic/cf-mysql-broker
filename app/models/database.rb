class Database
  def self.create(database_name)
    connection.execute("CREATE DATABASE IF NOT EXISTS `#{database_name}`")
  end

  def self.drop(database_name)
    connection.execute("DROP DATABASE IF EXISTS `#{database_name}`")
  end

  # why not "SHOW DATABASES LIKE '#{id}'" ??
  def self.exists?(database_name)
    1 == connection.select("SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE schema_name='#{database_name}'").rows.first.first
  end

  private

  def self.connection
    ActiveRecord::Base.connection
  end

  def connection
    self.class.connection
  end
end
