class AppSettings < Settingslogic
  case ENV['RAILS_ENV']
  when 'production'
    source Rails.root.join("config/app_settings_production.yml")
  when 'test'
    source Rails.root.join("config/app_settings_test.yml")
  else
    source Rails.root.join("config/app_settings_development.yml")
  end
end