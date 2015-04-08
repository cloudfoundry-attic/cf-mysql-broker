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
end
