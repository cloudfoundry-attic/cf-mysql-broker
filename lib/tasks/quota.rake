namespace :quota do
  desc 'Enforce quotas'
  task :enforce => :environment do
    Quota::Enforcer.enforce!
  end
end
