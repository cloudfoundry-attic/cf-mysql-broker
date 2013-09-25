class AppSettings < Settingslogic
  source Rails.root.join("config/app_settings.yml")
  namespace Rails.env
end