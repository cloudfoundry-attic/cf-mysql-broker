module QuotaEnforcer
  class << self
    def update_quotas
      update_service_instances_max_storage_mb
      update_max_user_connection_quota
    end

    def enforce!

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

    def get_broker_db_name
      ActiveRecord::Base.connection_config['database']
    end

    def update_max_user_connection_quota
      all_users.each do |username|
        begin
          grants = connection.execute("SHOW GRANTS FOR #{connection.quote(username)}")
          grants.each do |grant_list|
            grant = grant_list[0]
            if grant.start_with?('GRANT ALL PRIVILEGES ON `cf_')
              database_name = grant.split('`')[1]
              service_instance = ServiceInstance.find_by_db_name(database_name)
              ServiceBinding.update_connection_quota_for_user(username, service_instance)
            end
          end
        rescue ActiveRecord::StatementInvalid => e
          Rails.logger.info(e) unless e.message =~ /no such grant/
        end
      end
    end

    def all_users
      users = connection.execute("SELECT DISTINCT(USER) FROM mysql.user")
      users_array = []
      users.each do |u|
        users_array << u[0]
      end
      users_array
    end

    def update_service_instances_max_storage_mb
      broker_db = get_broker_db_name

      sub_query = generate_sub_query_from_catalog

      connection.execute(<<-SQL)
        UPDATE #{broker_db}.service_instances AS instances,
        (#{sub_query}) AS catalog
        SET instances.max_storage_mb = catalog.max_storage_mb
        WHERE instances.plan_guid = catalog.id
      SQL
    end

    def generate_sub_query_from_catalog
      sub_query = String.new
      Catalog.plans.each_with_index do |plan, index|
        if 0 == index
          sub_query.concat("SELECT '#{plan.id}' AS id, #{plan.max_storage_mb} AS max_storage_mb")
        else
          sub_query.concat(" UNION SELECT '#{plan.id}', #{plan.max_storage_mb}")
        end
      end
      sub_query
    end

    def revoke_privileges_from_violators
      broker_db = get_broker_db_name

      # This query selects all the databases which are both over quota and still have write privileges.
      violators = connection.select_values(<<-SQL)
        SELECT tables.table_schema AS db
        FROM   information_schema.tables AS tables
        JOIN   mysql.db AS dbs ON tables.table_schema = dbs.Db
        JOIN   #{broker_db}.service_instances AS instances ON tables.table_schema = instances.db_name COLLATE utf8_general_ci
        WHERE  (dbs.Insert_priv = 'Y' OR dbs.Update_priv = 'Y' OR dbs.Create_priv = 'Y')
        GROUP  BY tables.table_schema
        HAVING ROUND(SUM(tables.data_length + tables.index_length) / 1024 / 1024, 1) >= MAX(instances.max_storage_mb)
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
      broker_db = get_broker_db_name

      # This query selects all the databases which are both under quota but do not have write privileges.
      reformed = connection.select_values(<<-SQL)
        SELECT tables.table_schema AS db
        FROM   information_schema.tables AS tables
        JOIN   mysql.db AS dbs ON tables.table_schema = dbs.Db
        JOIN   #{broker_db}.service_instances AS instances ON tables.table_schema = instances.db_name COLLATE utf8_general_ci
        WHERE  (dbs.Insert_priv = 'N' OR dbs.Update_priv = 'N' OR dbs.Create_priv = 'N')
        GROUP  BY tables.table_schema
        HAVING ROUND(SUM(tables.data_length + tables.index_length) / 1024 / 1024, 1) < MAX(instances.max_storage_mb)
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
          begin
            connection.execute("KILL CONNECTION #{id}")
          rescue ActiveRecord::StatementInvalid => e
            raise unless e.message =~ /Unknown thread id/
          end
        end
      end
    end
  end
end
