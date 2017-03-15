class RevokeAbilityToLockTables < ActiveRecord::Migration
  def up
    select_rows("SELECT User, Db, Host FROM mysql.db WHERE Lock_tables_priv='Y'").each do |user, db, host|
      execute "REVOKE LOCK TABLES ON #{db}.* FROM '#{user}'@'#{host}'"
    end
  end
end
