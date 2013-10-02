class V2::ServiceInstancesController < V2::BaseController
  # This is actually the create
  def update
    dbname = DatabaseName.new(params[:id])
    ActiveRecord::Base.connection.execute("CREATE DATABASE #{dbname.name};")

    render status: 201, json: { dashboard_url: 'http://fake.dashboard.url' }
  end

  def destroy
    dbname = DatabaseName.new(params[:id])

    if ActiveRecord::Base.connection.select("SHOW DATABASES LIKE '#{dbname.name}';").any?
      # Even though we just checked to see that the database exists, we
      # should still guard against its absence with IF EXISTS in case
      # we're racing another delete request.
      ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS #{dbname.name};")
      status = 204
    else
      status = 410
    end

    render status: status, json: {}
  end
end
