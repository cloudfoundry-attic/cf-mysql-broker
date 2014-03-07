class ServiceInstancePermissionsRevokedQuery
  attr_reader :instance

  def initialize(instance)
    @instance = instance
  end

  def execute
    escaped_database = ActiveRecord::Base.sanitize(instance.database)
    query = <<-SQL
      SELECT COUNT(*)
      FROM mysql.db
      WHERE Db = #{escaped_database} AND (Insert_priv = 'N' OR Update_priv = 'N' OR Create_priv = 'N')
    SQL

    count = ActiveRecord::Base.connection.select_value(query)

    count != 0
  end

end
