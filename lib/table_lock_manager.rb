class TableLockManager
  def self.update_table_lock_permissions
    connection = ActiveRecord::Base.connection
    if Settings.allow_table_locks
      connection.select_rows("SELECT User, Db, Host FROM mysql.db WHERE Lock_tables_priv='N'").each do |user, db, host|
        next unless user.present?
        connection.execute "GRANT LOCK TABLES ON `#{db}`.* TO '#{user}'@'#{host}'"
      end
    else
      connection.select_rows("SELECT User, Db, Host FROM mysql.db WHERE Lock_tables_priv='Y'").each do |user, db, host|
        next unless user.present? && db.present?
        connection.execute "REVOKE LOCK TABLES ON `#{db}`.* FROM '#{user}'@'#{host}'"
      end
    end
  end
end
