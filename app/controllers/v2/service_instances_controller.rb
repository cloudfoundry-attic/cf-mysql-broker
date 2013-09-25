class V2::ServiceInstancesController < V2::BaseController

  # This is actually the create
  def update
    dbname = DatabaseName.new(params[:id])
    ActiveRecord::Base.connection.execute("CREATE DATABASE #{dbname.name};")

    render status: 201, json: { dashboard_url: 'http://fake.dashboard.url' }
  end

  def destroy
    dbname = DatabaseName.new(params[:id])
    ActiveRecord::Base.connection.execute("DROP DATABASE #{dbname.name};")

    render status: 204, json: {}
  end
end
