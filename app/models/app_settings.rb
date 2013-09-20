class AppSettings < Settingslogic
  # This points at /var/vcap/packages, not /var/vcap/jobs which is where
  # BOSH renders the config templates.
  #source Rails.root.join("config/app_settings.yml")

  source '/var/vcap/jobs/cf-mysql-broker/config/app_settings.yml'
end