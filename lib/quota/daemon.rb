module Quota
  module Daemon
    def self.start
      dbconfig = YAML.load(File.read(Settings.database_config_path))
      ActiveRecord::Base.establish_connection(dbconfig[Rails.env])

      Enforcer.update_quotas

      Kernel.loop do
        Database.with_reconnect do
          Enforcer.enforce!
        end
        Kernel.sleep(1.second)
      end
    end
  end
end
