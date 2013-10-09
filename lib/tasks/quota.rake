namespace :quota do
  desc 'Enforce quotas'
  task :enforce => :environment do
    QuotaEnforcer.enforce!
  end
end
