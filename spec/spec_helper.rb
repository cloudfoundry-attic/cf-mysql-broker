require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'rspec/autorun'
require 'webmock/rspec'
require 'database_cleaner'

DatabaseCleaner.strategy = :truncation
WebMock.disable_net_connect!(allow: 'codeclimate.com')

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = true

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  #
  # Our tests won't work with the default localhost wildcard user record in mysql
  # We also need a few innodb settings in order for stats to update automatically.
  #
  config.before :suite do
    count_of_bad_users = ActiveRecord::Base.connection.select_value("select count(*) from mysql.user where Host='localhost' and User=''")
    if count_of_bad_users > 0
      raise %Q{You must delete the Host='localhost' User='' record from the mysql.users table.\nRun this command:\nmysql -u root -e "DELETE FROM mysql.user WHERE Host='localhost' AND User=''"}
    end

    variable_records = ActiveRecord::Base.connection.select("show variables like 'innodb_stats_%'")
    variables = Hash[
      variable_records.map { |record| [record['Variable_name'], record['Value']] }
    ]

    raise <<-TEXT.strip_heredoc unless variables['innodb_stats_on_metadata'] == 'ON'
    innodb_stats_on_metadata must be ON
      Option 1 (permanent): set innodb_stats_on_metadata=ON in my.cnf
      Option 2 (temporary): in mysql CLI, "set global innodb_stats_on_metadata=ON"
    TEXT
    raise <<-TEXT.strip_heredoc if variables['innodb_stats_persistent'] == 'ON'
    innodb_stats_persistent must be OFF
      Option 1 (permanent): set innodb_stats_persistent=OFF in my.cnf
      Option 2 (temporary): in mysql CLI, "set global innodb_stats_persistent=OFF"
    TEXT
  end

  config.after do
    DatabaseCleaner.clean
  end
end
