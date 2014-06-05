require Rails.root.join('app/models/base_model')
require Rails.root.join('lib/service_instance_manager')

module QuotaEnforcer
  QUOTA_IN_MB = Settings.services[0].plans[0].max_storage_mb.to_i rescue nil

  class << self
    def enforce!
      raise 'You must specify a service and a plan' if QUOTA_IN_MB == nil

      # When debugging, the following code will show you the list of databases and their usage:
      #
      #     pp connection.select(<<-SQL).rows.map { |result| {database: result[0], usage: result[1].to_f} }
      #       SELECT tables.table_schema as 'database', ROUND(SUM(tables.data_length + tables.index_length) / 1024 / 1024, 1) as 'usage'
      #       FROM   information_schema.tables tables
      #       WHERE  tables.table_schema LIKE '#{ServiceInstance::DATABASE_PREFIX}%'
      #       GROUP  BY tables.table_schema
      #     SQL

      revoke_privileges_from_violators
      grant_privileges_to_reformed
    end

    private

    def connection
      ActiveRecord::Base.connection
    end

    def revoke_privileges_from_violators
      # This query selects all the databases which are both over quota and still have write privileges.
      violators = connection.select_values(<<-SQL)
        SELECT tables.table_schema as 'database'
        FROM   information_schema.tables tables
        JOIN   mysql.db dbs ON tables.table_schema = dbs.Db
        WHERE  tables.table_schema LIKE '#{ServiceInstanceManager::DATABASE_PREFIX}%' AND (dbs.Insert_priv = 'Y' OR dbs.Update_priv = 'Y' OR dbs.Create_priv = 'Y')
        GROUP  BY tables.table_schema
        HAVING ROUND(SUM(tables.data_length + tables.index_length) / 1024 / 1024, 1) >= #{QUOTA_IN_MB}
      SQL

      violators.each do |database|
        Rails.logger.info "#{Time.now}: Database over quota #{database.inspect}, removing privileges"
        connection.update(<<-SQL)
          UPDATE mysql.db
          SET    Insert_priv = 'N', Update_priv = 'N', Create_priv = 'N'
          WHERE  Db = '#{database}'
        SQL

        reset_active_privileges(database)
      end
    end

    def grant_privileges_to_reformed
      # This query selects all the databases which are both under quota but do not have write privileges.
      reformed = connection.select_values(<<-SQL)
        SELECT tables.table_schema as 'database'
        FROM   information_schema.tables tables
        JOIN   mysql.db dbs ON tables.table_schema = dbs.Db
        WHERE  tables.table_schema LIKE '#{ServiceInstanceManager::DATABASE_PREFIX}%' AND (dbs.Insert_priv = 'N' OR dbs.Update_priv = 'N' OR dbs.Create_priv = 'N')
        GROUP  BY tables.table_schema
        HAVING ROUND(SUM(tables.data_length + tables.index_length) / 1024 / 1024, 1) < #{QUOTA_IN_MB}
      SQL

      reformed.each do |database|
        Rails.logger.info "#{Time.now}: Database now under quota #{database.inspect}, reinstating privileges"
        connection.update(<<-SQL)
          UPDATE mysql.db
          SET    Insert_priv = 'Y', Update_priv = 'Y', Create_priv = 'Y'
          WHERE  Db = '#{database}'
        SQL

        reset_active_privileges(database)
      end
    end

    #
    # In order to change privileges immediately, we must do two things:
    # 1) Flush the privileges
    # 2) Kill any and all active connections
    #
    def reset_active_privileges(database)
      connection.execute('FLUSH PRIVILEGES')

      processes = connection.select('SHOW PROCESSLIST')
      processes.each do |process|
        id, db, user = process.values_at('Id', 'db', 'User')

        if db == database && user != 'root'
          connection.execute("KILL CONNECTION #{id}")
        end
      end
    end
  end
end
