class V2::ServiceInstancesController < V2::BaseController

  # This is actually the create
  def update
    dbname = DatabaseName.new(params[:id])
    ActiveRecord::Base.connection.execute("CREATE DATABASE #{dbname.name};")

    render status: 201, json: { dashboard_url: 'http://fake.dashboard.url' }
  end

  def destroy
    dbname = DatabaseName.new(params[:id])

    # Need to use update() in order to get the number of databases dropped
    count = ActiveRecord::Base.connection.update("DROP DATABASE IF EXISTS #{dbname.name};").to_i

    status = count == 0 ? 410 : 204

    render status: status, json: {}
  end
end
