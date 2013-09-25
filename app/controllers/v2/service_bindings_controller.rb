
class V2::ServiceBindingsController < V2::BaseController

  def update

    # This will become more complicated when we have multiple nodes
    database_settings =  Rails.configuration.database_configuration[Rails.env]
    database_host = database_settings.fetch('host')
    database_port = database_settings.fetch('port')

    database_name = DatabaseName.new(params.fetch(:service_instance_id)).name

    binding_id= params.fetch(:id)
    creds = UserCreds.new(binding_id)

    base_database_url = "mysql://#{creds.username}:#{creds.password}@#{database_host}:#{database_port}/#{database_name}"

    ActiveRecord::Base.connection.execute("CREATE USER '#{creds.username}' IDENTIFIED BY '#{creds.password}';")
    ActiveRecord::Base.connection.execute("GRANT ALL PRIVILEGES ON #{database_name}.* TO '#{creds.username}';")
    ActiveRecord::Base.connection.execute("FLUSH PRIVILEGES;")

    render status: 201, :json => {
        'credentials' => {
            'hostname' => database_host,
            'name'     => database_name,
            'username' => creds.username,
            'password' => creds.password,
            'port'     => database_port,
            'jdbcUrl'  => "jdbc:#{base_database_url}",
            'uri'      => "#{base_database_url}?reconnect=true",
        }
    }.to_json
  end

  def destroy
    binding_id = params.fetch(:id)
    creds = UserCreds.new(binding_id)
    status = 204

    begin
      # There is no DROP USER IF EXISTS, unfortunately
      ActiveRecord::Base.connection.execute("DROP USER '#{creds.username}';")
    rescue ActiveRecord::StatementInvalid
      status = 410
    end

    ActiveRecord::Base.connection.execute("FLUSH PRIVILEGES;")

    render status: status, json: {}
  end
end
