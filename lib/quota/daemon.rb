module Quota
  module Daemon
    def self.start
      dbconfig = YAML.load(File.read(Settings.database_config_path))
      ActiveRecord::Base.establish_connection(dbconfig[Rails.env])

      Rails.logger = Logger.new(STDOUT)
      Enforcer.update_quotas

      loop do
        Enforcer.enforce!
        sleep 1
      end
    end
  end
end
