require 'spec_helper'

describe QuotaEnforcer do
  describe '.enforce!' do
    let(:instance1_guid) { SecureRandom.uuid }
    let(:instance1) { ServiceInstance.find_by_guid(instance1_guid) }

    let(:binding1_id) { SecureRandom.uuid }
    let(:binding1) { ServiceBinding.new(id: binding1_id, service_instance: instance1) }

    let(:instance2_guid) { SecureRandom.uuid }
    let(:instance2) { ServiceInstance.find_by_guid(instance2_guid) }

    let(:binding2_id) { SecureRandom.uuid }
    let(:binding2) { ServiceBinding.new(id: binding2_id, service_instance: instance2) }

    let(:bindings) { [binding1, binding2] }

    let(:service) { Service.build(
      'id' => SecureRandom.uuid,
      'name' => 'our service',
      'description' => 'our service',
      'plans' => [plan1, plan2, plan3]
    )}

    let(:max_storage_mb_for_plan_1) { 5 }
    let(:max_storage_mb_for_plan_2) { 10 }
    let(:max_storage_mb_for_plan_3) { 15 }

    let(:plan1) {{
      'id' => 'plan-1-guid',
      'name' => 'plan-1',
      'description' => 'plan-1-desc',
      'max_storage_mb' => max_storage_mb_for_plan_1
    }}

    let(:plan2) {{
      'id' => 'plan-2-guid',
      'name' => 'plan-2',
      'description' => 'plan-2-desc',
      'max_storage_mb' => max_storage_mb_for_plan_2
    }}

    let(:plan3) {{
      'id' => 'plan-3-guid',
      'name' => 'plan-3',
      'description' => 'plan-3-desc',
      'max_storage_mb' => max_storage_mb_for_plan_3
    }}

    before do
      Catalog.stub(:services) { [service] }

      ServiceInstanceManager.create(guid: instance1_guid, plan_guid: 'plan-1-guid' )
      ServiceInstanceManager.create(guid: instance2_guid, plan_guid: 'plan-2-guid' )
      binding1.save
      binding2.save

      # No instance / binding for plan 3 to test enforcer works for plans with no instance
    end

    after do
      bindings.each { |binding| binding.destroy }
      ServiceInstanceManager.destroy(guid: instance1_guid)
      ServiceInstanceManager.destroy(guid: instance2_guid)
    end

    context 'for a database that has just moved over its quota' do
      before do
        client1 = create_mysql_client(binding1)
        client2 = create_mysql_client(binding2)

        overflow_database(client1, max_storage_mb_for_plan_1)
        recalculate_usage(binding1)
        overflow_database(client2, max_storage_mb_for_plan_2)
        recalculate_usage(binding2)
      end

      it 'revokes insert, update, and create privileges' do
        QuotaEnforcer.enforce!

        bindings.each do |binding|
          client = create_mysql_client(binding)
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
      end

      it 'kills existing connections' do
        clients = bindings.map do |binding|
          create_mysql_client(binding)
        end

        clients.each { |client| client.query('SELECT 1') }

        QuotaEnforcer.enforce!

        clients.each do |client|
          expect {
            client.query('SELECT 1')
          }.to raise_error(Mysql2::Error, /server has gone away/)
        end
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
        client1 = create_mysql_client(binding1)
        client2 = create_mysql_client(binding2)

        overflow_database(client1, max_storage_mb_for_plan_1)
        recalculate_usage(binding1)
        overflow_database(client2, max_storage_mb_for_plan_2)
        recalculate_usage(binding2)

        QuotaEnforcer.enforce!
      end

      it 'does not kill existing connections' do
        clients = bindings.map do |binding|
          create_mysql_client(binding)
        end

        clients.each { |client| client.query('SELECT 1') }

        QuotaEnforcer.enforce!

        clients.each do |client|
          expect {
            client.query('SELECT 1')
          }.to_not raise_error
        end
      end
    end

    context 'for a database that has just moved under its quota' do
      before do
        client1 = create_mysql_client(binding1)
        client2 = create_mysql_client(binding2)

        overflow_database(client1, max_storage_mb_for_plan_1)
        recalculate_usage(binding1)
        overflow_database(client2, max_storage_mb_for_plan_2)
        recalculate_usage(binding2)

        QuotaEnforcer.enforce!

        client1 = create_mysql_client(binding1)
        client2 = create_mysql_client(binding2)
        prune_database(client1)
        prune_database(client2)
        recalculate_usage(binding1)
        recalculate_usage(binding2)
      end

      it 'grants insert, update, and create privileges' do
        QuotaEnforcer.enforce!

        bindings.each do |binding|
          client = create_mysql_client(binding)
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
      end

      it 'kills existing connections' do
        clients = bindings.map do |binding|
          create_mysql_client(binding)
        end

        clients.each do |client|
          client.query('SELECT 1')
        end

        QuotaEnforcer.enforce!

        clients.each do |client|
          expect {
            client.query('SELECT 1')
          }.to raise_error(Mysql2::Error, /server has gone away/)
        end
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
        client1 = create_mysql_client(binding1)
        client2 = create_mysql_client(binding2)

        overflow_database(client1, max_storage_mb_for_plan_1)
        recalculate_usage(binding1)
        overflow_database(client2, max_storage_mb_for_plan_2)
        recalculate_usage(binding2)

        QuotaEnforcer.enforce!

        client1 = create_mysql_client(binding1)
        client2 = create_mysql_client(binding2)
        prune_database(client1)
        prune_database(client2)
        recalculate_usage(binding1)
        recalculate_usage(binding2)

        QuotaEnforcer.enforce!
      end

      it 'does not kill existing connections' do
        clients = bindings.map do |binding|
          create_mysql_client(binding)
        end

        clients.each do |client|
          client.query('SELECT 1')
        end

        QuotaEnforcer.enforce!

        clients.each do |client|
          expect {
            client.query('SELECT 1')
          }.to_not raise_error
        end
      end
    end

    context 'for a database with a plan that the quota has been changed' do
      before do

        client1 = create_mysql_client(binding1)
        client2 = create_mysql_client(binding2)

        overflow_database(client1, max_storage_mb_for_plan_1)
        recalculate_usage(binding1)
        overflow_database(client2, max_storage_mb_for_plan_2)
        recalculate_usage(binding2)

        QuotaEnforcer.enforce!

        plan1 = {
          'id' => 'plan-1-guid',
          'name' => 'plan-1',
          'description' => 'plan-1-desc',
          'max_storage_mb' => max_storage_mb_for_plan_1 + 10
        }

        service = Service.build(
          'id' => SecureRandom.uuid,
          'name' => 'our service',
          'description' => 'our service',
          'plans' => [plan1, plan2, plan3]
        )

        Catalog.stub(:services) { [service] }
      end

      it 'grants insert, update, and create privileges to only the plan that was changed' do
        QuotaEnforcer.enforce!

        client1 = create_mysql_client(binding1)
        expect {
          client1.query("INSERT INTO stuff (id, data) VALUES (99999, 'This should succeed.')")
        }.to_not raise_error

        expect {
          client1.query("UPDATE stuff SET data = 'This should also succeed.' WHERE id = 99999")
        }.to_not raise_error

        expect {
          client1.query('CREATE TABLE more_stuff (id INT PRIMARY KEY)')
        }.to_not raise_error

        expect {
          client1.query('SELECT COUNT(*) FROM stuff')
        }.to_not raise_error

        expect {
          client1.query('DELETE FROM stuff WHERE id = 99999')
        }.to_not raise_error


        client2 = create_mysql_client(binding2)
        expect {
          client2.query("INSERT INTO stuff (id, data) VALUES (99999, 'This should fail.')")
        }.to raise_error(Mysql2::Error, /INSERT command denied/)

        expect {
          client2.query("UPDATE stuff SET data = 'This should also fail.' WHERE id = 1")
        }.to raise_error(Mysql2::Error, /UPDATE command denied/)

        expect {
          client2.query('CREATE TABLE more_stuff (id INT PRIMARY KEY)')
        }.to raise_error(Mysql2::Error, /CREATE command denied/)

        expect {
          client2.query('SELECT COUNT(*) FROM stuff')
        }.to_not raise_error

        expect {
          client2.query('DELETE FROM stuff WHERE id = 1')
        }.to_not raise_error
      end

    end

    context 'when a database has a plan that no longer exists' do

    end

    def create_mysql_client(binding)
      Mysql2::Client.new(
        :host     => binding.host,
        :port     => binding.port,
        :database => binding.database_name,
        :username => binding.username,
        :password => binding.password
      )
    end

    def create_root_mysql_client
      config = Rails.configuration.database_configuration[Rails.env]

      Mysql2::Client.new(
        :host     => binding1.host,
        :port     => binding1.port,
        :database => binding1.database_name,
        :username => config.fetch('username'),
        :password => config.fetch('password')
      )
    end

    def overflow_database(client, max_mb)
      client.query('CREATE TABLE stuff (id INT PRIMARY KEY, data LONGTEXT) ENGINE=InnoDB')
      client.query('CREATE TABLE stuff2 (id INT PRIMARY KEY, data LONGTEXT) ENGINE=InnoDB')

      data = '1' * (1024 * 512) # 0.5 MB
      data = client.escape(data)

      max_mb.times do |n|
        client.query("INSERT INTO stuff (id, data) VALUES (#{n}, '#{data}')")
        client.query("INSERT INTO stuff2 (id, data) VALUES (#{n}, '#{data}')")
      end
    end

    def prune_database(client)
      client.query('DELETE FROM stuff')
      client.query('DELETE FROM stuff2')
    end

    # Force MySQL to immediately recalculate table usage. Normally
    # there can be a 5+ second delay. Forcing the calculation here
    # allows us to immediately test the quota enforcer, as this will
    # ensure it has the latest usage stats with which to make its
    # enforcement decisions.
    def recalculate_usage(binding)
      # For some reason, ANALYZE TABLE doesn't update statistics in Travis' environment
      ActiveRecord::Base.connection.execute("OPTIMIZE TABLE #{binding.database_name}.stuff")
      ActiveRecord::Base.connection.execute("OPTIMIZE TABLE #{binding.database_name}.stuff2")
    end
  end
end
