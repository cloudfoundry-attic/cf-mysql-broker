ENV['SETTINGS_PATH'] ||= File.expand_path('../../config/settings.yml', __FILE__)

class Settings < Settingslogic
  source ENV['SETTINGS_PATH']
  namespace Rails.env
end
