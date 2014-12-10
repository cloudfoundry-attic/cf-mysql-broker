module Quota
  module Daemon
    def self.start
      dbconfig = YAML.load(File.read(Settings.database_config_path))
      ActiveRecord::Base.establish_connection(dbconfig[Rails.env])

      Enforcer.update_quotas

      Kernel.loop do
        Enforcer.enforce!
        Kernel.sleep(1)
      end
    end
  end
end
