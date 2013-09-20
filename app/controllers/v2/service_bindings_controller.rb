class V2::ServiceBindingsController < V2::BaseController

  def update
    database_settings = AppSettings.database
    database_ip = database_settings.ip
    database_name = database_settings.singleton_database
    database_user = database_settings.admin_user
    database_password = database_settings.admin_password
    database_port = database_settings.port

    base_database_url = "mysql://#{database_user}:#{database_password}@#{database_ip}:#{database_port}/#{database_name}"

    render status: 201, :json => {
        'credentials' => {
            'hostname' => database_ip,
            'name'     => database_name,
            'username' => database_user,
            'password' => database_password,
            'port'     => database_port,
            'jdbcUrl'  => "jdbc:#{base_database_url}",
            'uri'      => "#{base_database_url}?reconnect=true",
        }
    }.to_json
  end

  def destroy
    render status: 204, json: {}
  end
end
