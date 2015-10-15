# Sync our services instances with the source of truth in Settings.plans on startup

unless Rails.env.assets?
  ServiceInstanceManager.sync_service_instances
end

