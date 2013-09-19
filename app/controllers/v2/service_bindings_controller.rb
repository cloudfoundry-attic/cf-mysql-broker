class V2::ServiceBindingsController < V2::BaseController

  CREDS = {
      jdbcUrl: "jdbc:mysql://testuser:testpassword@testdb.csvbuoabzxev.us-east-1.rds.amazonaws.com:3306/testdb",
      uri: "mysql://testuser:testpassword@testdb.csvbuoabzxev.us-east-1.rds.amazonaws.com:3306/testdb?reconnect=true",
      name: "fun",
      hostname: "testdb.csvbuoabzxev.us-east-1.rds.amazonaws.com",
      port: "3306",
      username: "testuser",
      password: "testpassword"
  }

  # This is actually the create
  def update
    render status: 201, json: { credentials: CREDS.to_json }
  end

  def destroy
    render status: 204, json: {}
  end
end
