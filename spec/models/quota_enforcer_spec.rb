require 'spec_helper'

describe QuotaEnforcer do
  describe '.enforce!' do
    let(:instance_id) { SecureRandom.uuid }
    let(:instance) { ServiceInstance.new(id: instance_id) }

    let(:binding_id) { SecureRandom.uuid }
    let(:binding) { ServiceBinding.new(id: binding_id, service_instance: instance) }

    let(:max_storage_mb) { Settings.services[0].plans[0].max_storage_mb.to_i }

    before do
      instance.save
      binding.save
    end

    after do
      binding.destroy
      instance.destroy
    end

    context 'for a database that has just moved over its quota' do
      before do
        client = create_mysql_client
        overflow_database(client)
      end

      it 'revokes insert, update, and create privileges' do
        QuotaEnforcer.enforce!

        client = create_mysql_client
        expect {
          client.query("INSERT INTO stuff (id, data) VALUES (99999, 'This should fail.')")
        }.to raise_error(Mysql2::Error, /INSERT command denied/)

        expect {
          client.query("UPDATE stuff SET data = 'This should also fail.' WHERE id = 1")
        }.to raise_error(Mysql2::Error, /UPDATE command denied/)

        expect {
          client.query('CREATE TABLE more_stuff (id INT PRIMARY KEY)')
        }.to raise_error(Mysql2::Error, /CREATE command denied/)

        expect {
          client.query('SELECT COUNT(*) FROM stuff')
        }.to_not raise_error

        expect {
          client.query('DELETE FROM stuff WHERE id = 1')
        }.to_not raise_error
      end

      it 'kills existing connections' do
        client = create_mysql_client
        client.query('SELECT 1')

        QuotaEnforcer.enforce!

        expect {
          client.query('SELECT 1')
        }.to raise_error(Mysql2::Error, /server has gone away/)
      end

      it 'does not kill root connections' do
        client = create_root_mysql_client
        client.query('SELECT 1')

        QuotaEnforcer.enforce!

        expect {
          client.query('SELECT 1')
        }.to_not raise_error
      end
    end

    context 'for a database that has already moved over its quota' do
      before do
        client = create_mysql_client
        overflow_database(client)
        QuotaEnforcer.enforce!
      end

      it 'does not kill existing connections' do
        client = create_mysql_client
        client.query('SELECT 1')

        QuotaEnforcer.enforce!

        expect {
          client.query('SELECT 1')
        }.to_not raise_error
      end
    end

    context 'for a database that has just moved under its quota' do
      before do
        client = create_mysql_client
        overflow_database(client)
        QuotaEnforcer.enforce!

        client = create_mysql_client
        prune_database(client)
      end

      it 'grants insert, update, and create privileges' do
        QuotaEnforcer.enforce!

        client = create_mysql_client
        expect {
          client.query("INSERT INTO stuff (id, data) VALUES (99999, 'This should succeed.')")
        }.to_not raise_error

        expect {
          client.query("UPDATE stuff SET data = 'This should also succeed.' WHERE id = 99999")
        }.to_not raise_error

        expect {
          client.query('CREATE TABLE more_stuff (id INT PRIMARY KEY)')
        }.to_not raise_error

        expect {
          client.query('SELECT COUNT(*) FROM stuff')
        }.to_not raise_error

        expect {
          client.query('DELETE FROM stuff WHERE id = 99999')
        }.to_not raise_error
      end

      it 'kills existing connections' do
        client = create_mysql_client
        client.query('SELECT 1')

        QuotaEnforcer.enforce!

        expect {
          client.query('SELECT 1')
        }.to raise_error(Mysql2::Error, /server has gone away/)
      end

      it 'does not kill root connections' do
        client = create_root_mysql_client
        client.query('SELECT 1')

        QuotaEnforcer.enforce!

        expect {
          client.query('SELECT 1')
        }.to_not raise_error
      end
    end

    context 'for a database that has already moved under its quota' do
      before do
        client = create_mysql_client
        overflow_database(client)
        QuotaEnforcer.enforce!

        client = create_mysql_client
        prune_database(client)
        QuotaEnforcer.enforce!
      end

      it 'does not kill existing connections' do
        client = create_mysql_client
        client.query('SELECT 1')

        QuotaEnforcer.enforce!

        expect {
          client.query('SELECT 1')
        }.to_not raise_error
      end
    end

    def create_mysql_client
      Mysql2::Client.new(
        :host     => binding.host,
        :port     => binding.port,
        :database => binding.database,
        :username => binding.username,
        :password => binding.password
      )
    end

    def create_root_mysql_client
      config = Rails.configuration.database_configuration[Rails.env]

      Mysql2::Client.new(
        :host     => binding.host,
        :port     => binding.port,
        :database => binding.database,
        :username => config.fetch('username'),
        :password => config.fetch('password')
      )
    end

    def overflow_database(client)
      client.query('CREATE TABLE stuff (id INT PRIMARY KEY, data LONGTEXT) ENGINE=InnoDB')

      data = '1' * (1024 * 1024) # 1 MB
      data = client.escape(data)

      max_storage_mb.times do |n|
        client.query("INSERT INTO stuff (id, data) VALUES (#{n}, '#{data}')")
      end

      recalculate_usage
    end

    def prune_database(client)
      client.query('DELETE FROM stuff')

      recalculate_usage
    end

    # Force MySQL to immediately recalculate table usage. Normally
    # there can be a 5+ second delay. Forcing the calculation here
    # allows us to immediately test the quota enforcer, as this will
    # ensure it has the latest usage stats with which to make its
    # enforcement decisions.
    def recalculate_usage
      # For some reason, ANALYZE TABLE doesn't update statistics in Travis' environment
      #ActiveRecord::Base.connection.execute("OPTIMIZE TABLE #{binding.database}.stuff")
    end
  end
end
