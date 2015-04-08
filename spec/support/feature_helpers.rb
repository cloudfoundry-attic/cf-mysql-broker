# Inspired by rspec-rails' request example group.
module FeatureHelpers
  extend ActiveSupport::Concern
  include ActionDispatch::Integration::Runner

  included do
    metadata[:type] = :feature

    let(:default_env) do
      username = Settings.auth_username
      password = Settings.auth_password

      {
        'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
      }
    end
    let(:env) { default_env }

    before do
      @routes = ::Rails.application.routes
    end
  end

  def app
    ::Rails.application
  end

  def get(*args)
    args[2] ||= env
    super(*args)
  end

  def post(*args)
    args[2] ||= env
    super(*args)
  end

  def put(*args)
    args[2] ||= env
    super(*args)
  end

  def patch(*args)
    args[2] ||= env
    super(*args)
  end

  def delete(*args)
    args[2] ||= env
    super(*args)
  end

  def create_mysql_client(config)
    Mysql2::Client.new(
      :host => config.fetch('hostname'),
      :port => config.fetch('port'),
      :database => config.fetch('name'),
      :username => config.fetch('username'),
      :password => config.fetch('password')
    )
  end

  def create_table_and_write_data(client, max_storage_mb)
    client.query('DROP TABLE IF EXISTS stuff')
    client.query('CREATE TABLE stuff (id INT PRIMARY KEY, data LONGTEXT) ENGINE=InnoDB')

    data = '1' * (1024 * 1024) # 1 MB

    max_storage_mb.times do |n|
      client.query("INSERT INTO stuff (id, data) VALUES (#{n}, '#{data}')")
    end
  end

  def verify_client_can_write(client)
    client.query("INSERT INTO stuff (id, data) VALUES (99999, 'This should succeed.')")
    client.query("UPDATE stuff SET data = 'This should also succeed.' WHERE id = 99999")
  end
end

RSpec.configure do |config|
  config.include FeatureHelpers, :example_group => { :file_path => %r(spec/features) }
end
