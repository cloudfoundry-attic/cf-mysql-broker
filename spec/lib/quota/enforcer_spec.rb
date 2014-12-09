require 'spec_helper'
require 'support/mysql_helper'

describe Quota::Enforcer do
  include MysqlHelpers

  let(:instance1_guid) { SecureRandom.uuid }
  let(:instance1) { ServiceInstance.find_by_guid(instance1_guid) }

  let(:binding1_id) { SecureRandom.uuid }
  let(:binding1) { ServiceBinding.new(id: binding1_id, service_instance: instance1) }

  let(:instance2_guid) { SecureRandom.uuid }
  let(:instance2) { ServiceInstance.find_by_guid(instance2_guid) }

  let(:binding2_id) { SecureRandom.uuid }
  let(:binding2) { ServiceBinding.new(id: binding2_id, service_instance: instance2) }

  let(:binding3_id) { SecureRandom.uuid }
  let(:binding3) { ServiceBinding.new(id: binding3_id, service_instance: instance1) }

  let(:bindings) { [binding1, binding2] }

  let(:service) { Service.build(
    'id' => SecureRandom.uuid,
    'name' => 'our service',
    'description' => 'our service',
    'plans' => [plan1, plan2, plan3]
  )}

  let(:max_storage_mb_for_plan_1) { 2 }
  let(:max_storage_mb_for_plan_2) { 4 }
  let(:max_storage_mb_for_plan_3) { 6 }

  let(:max_user_connections_for_plan_1) { 40 }

  let(:plan1) {{
    'id' => 'plan-1-guid',
    'name' => 'plan-1',
    'description' => 'plan-1-desc',
    'max_storage_mb' => max_storage_mb_for_plan_1,
    'max_user_connections' => max_user_connections_for_plan_1
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
    binding3.save

    # No instance / binding for plan 3 to test enforcer works for plans with no instance
  end

  after do
    bindings.each { |binding| binding.destroy }
    binding3.destroy
    ServiceInstanceManager.destroy(guid: instance1_guid)
    ServiceInstanceManager.destroy(guid: instance2_guid)
  end

  describe '.update_quotas' do
    it 'updates the quotas for max storage and user connections' do
      expect(instance1.max_storage_mb).to eq(max_storage_mb_for_plan_1)
      expect(max_user_connection_quota(binding1)).to eq(max_user_connections_for_plan_1)

      new_max_user_connections = 20
      new_max_storage_mb = 3

      updated_plan = {
          'id' => 'plan-1-guid',
          'name' => 'plan-1',
          'description' => 'plan-1-desc',
          'max_storage_mb' => new_max_storage_mb,
          'max_user_connections' => new_max_user_connections
      }
      updated_service = Service.build(
          'id' => service.id,
          'name' => 'our service',
          'description' => 'our service',
          'plans' => [updated_plan, plan2, plan3]
        )
      Catalog.stub(:services) { [updated_service] }

      Quota::Enforcer.update_quotas

      expect(instance1.reload.max_storage_mb).to eq(new_max_storage_mb)
      expect(max_user_connection_quota(binding1)).to eq(new_max_user_connections)
    end
  end

  describe '.enforce!' do
    context 'for a database that has just moved over its quota' do
      before do
        client1 = create_mysql_client(binding1)
        client2 = create_mysql_client(binding2)

        overflow_database(client1, max_storage_mb_for_plan_1)
        recalculate_usage(binding1)
        overflow_database(client2, max_storage_mb_for_plan_2)
        recalculate_usage(binding2)
        Quota::Enforcer.update_quotas
      end

      context 'and the catalog has not changed' do
        it 'revokes insert, update, and create privileges' do
          Quota::Enforcer.enforce!

          bindings.each do |binding|
            verify_write_privileges_revoked_select_and_delete_allowed(binding)
          end
        end

        it 'kills existing connections' do
          clients = generate_clients_and_connections_for_all_bindings

          Quota::Enforcer.enforce!

          clients.each do |client|
            verify_connection_killed(client)
          end
        end

        it 'does not kill root connections' do
          verify_root_connections_are_not_killed
        end
      end

      context 'and the catalog has a plan that has been removed' do
        before do
          service = Service.build(
            'id' => SecureRandom.uuid,
            'name' => 'our service',
            'description' => 'our service',
            'plans' => [plan1, plan3]
          )

          Catalog.stub(:services) { [service] }
          Quota::Enforcer.update_quotas
        end

        it 'revokes insert, update, and create privileges' do
          Quota::Enforcer.enforce!

          bindings.each do |binding|
            verify_write_privileges_revoked_select_and_delete_allowed(binding)
          end
        end

        it 'kills existing connections' do
          clients = generate_clients_and_connections_for_all_bindings

          Quota::Enforcer.enforce!

          clients.each do |client|
            verify_connection_killed(client)
          end
        end

        it 'does not kill root connections' do
          verify_root_connections_are_not_killed
        end
      end

      context 'and the catalog has a plan where the quota has been changed' do
        before do
          plan1 = {
            'id' => 'plan-1-guid',
            'name' => 'plan-1',
            'description' => 'plan-1-desc',
            'max_storage_mb' => max_storage_mb_for_plan_1 + 4
          }

          service = Service.build(
            'id' => SecureRandom.uuid,
            'name' => 'our service',
            'description' => 'our service',
            'plans' => [plan1, plan2, plan3]
          )

          Catalog.stub(:services) { [service] }
          Quota::Enforcer.update_quotas
        end

        it 'grants insert, update, and create privileges to only the plan that was changed' do
          Quota::Enforcer.enforce!

          verify_write_privileges_allowed(binding1)
          verify_write_privileges_revoked_select_and_delete_allowed(binding2)
        end

        it 'kills existing connections for only the plan that was not changed' do
          clients = generate_clients_and_connections_for_all_bindings

          Quota::Enforcer.enforce!

          verify_connection_not_killed(clients[0])
          verify_connection_killed(clients[1])
        end

        it 'does not kill root connections' do
          verify_root_connections_are_not_killed
        end
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

        Quota::Enforcer.enforce!
      end

      context 'and the catalog has not changed' do
        it 'does not kill existing connections' do
          clients = generate_clients_and_connections_for_all_bindings

          Quota::Enforcer.enforce!

          clients.each do |client|
            verify_connection_not_killed(client)
          end
        end
      end

      context 'and the catalog has a plan that has been removed' do
        before do
          service = Service.build(
            'id' => SecureRandom.uuid,
            'name' => 'our service',
            'description' => 'our service',
            'plans' => [plan1, plan3]
          )

          Catalog.stub(:services) { [service] }
          Quota::Enforcer.update_quotas
        end

        it 'does not kill existing connections' do
          clients = generate_clients_and_connections_for_all_bindings

          Quota::Enforcer.enforce!

          clients.each do |client|
            verify_connection_not_killed(client)
          end
        end
      end

      context 'and the catalog has a plan where the quota has been changed' do
        before do
          plan1 = {
            'id' => 'plan-1-guid',
            'name' => 'plan-1',
            'description' => 'plan-1-desc',
            'max_storage_mb' => max_storage_mb_for_plan_1 + 4
          }

          service = Service.build(
            'id' => SecureRandom.uuid,
            'name' => 'our service',
            'description' => 'our service',
            'plans' => [plan1, plan2, plan3]
          )

          Catalog.stub(:services) { [service] }
          Quota::Enforcer.update_quotas
        end

        it 'kills existing connections for only the plan that was changed' do
          clients = generate_clients_and_connections_for_all_bindings

          Quota::Enforcer.enforce!

          verify_connection_killed(clients[0])
          verify_connection_not_killed(clients[1])
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

        Quota::Enforcer.enforce!

        client1 = create_mysql_client(binding1)
        client2 = create_mysql_client(binding2)
        prune_database(client1)
        prune_database(client2)
        recalculate_usage(binding1)
        recalculate_usage(binding2)
      end

      context 'and the catalog has not changed' do
        it 'grants insert, update, and create privileges' do
          Quota::Enforcer.enforce!

          bindings.each do |binding|
            verify_write_privileges_allowed(binding)
          end
        end

        it 'kills existing connections' do
          clients = generate_clients_and_connections_for_all_bindings

          Quota::Enforcer.enforce!

          clients.each do |client|
            verify_connection_killed(client)
          end
        end

        it 'does not kill root connections' do
          verify_root_connections_are_not_killed
        end
      end

      context 'and the catalog has a plan that has been removed' do
        before do
          service = Service.build(
            'id' => SecureRandom.uuid,
            'name' => 'our service',
            'description' => 'our service',
            'plans' => [plan1, plan3]
          )

          Catalog.stub(:services) { [service] }
          Quota::Enforcer.update_quotas
        end

        it 'grants insert, update, and create privileges' do
          Quota::Enforcer.enforce!

          bindings.each do |binding|
            verify_write_privileges_allowed(binding)
          end
        end

        it 'kills existing connections' do
          clients = generate_clients_and_connections_for_all_bindings

          Quota::Enforcer.enforce!

          clients.each do |client|
            verify_connection_killed(client)
          end
        end

        it 'does not kill root connections' do
          verify_root_connections_are_not_killed
        end
      end

      context 'and the catalog has a plan where the quota has been changed' do
        before do
          plan1 = {
            'id' => 'plan-1-guid',
            'name' => 'plan-1',
            'description' => 'plan-1-desc',
            'max_storage_mb' => -5
          }

          service = Service.build(
            'id' => SecureRandom.uuid,
            'name' => 'our service',
            'description' => 'our service',
            'plans' => [plan1, plan2, plan3]
          )

          Catalog.stub(:services) { [service] }
          Quota::Enforcer.update_quotas
        end

        it 'grants insert, update, and create privileges to only the plan that was not changed' do
          Quota::Enforcer.enforce!

          verify_write_privileges_revoked_select_and_delete_allowed(bindings[0])
          verify_write_privileges_allowed(bindings[1])
        end

        it 'kills existing connections for only the plan that was not changed' do
          clients = generate_clients_and_connections_for_all_bindings

          Quota::Enforcer.enforce!

          verify_connection_not_killed(clients[0])
          verify_connection_killed(clients[1])
        end

        it 'does not kill root connections' do
          verify_root_connections_are_not_killed
        end
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

        Quota::Enforcer.enforce!

        client1 = create_mysql_client(binding1)
        client2 = create_mysql_client(binding2)
        prune_database(client1)
        prune_database(client2)
        recalculate_usage(binding1)
        recalculate_usage(binding2)

        Quota::Enforcer.enforce!
      end

      context 'and the catalog has not changed' do
        it 'does not kill existing connections' do
          clients = generate_clients_and_connections_for_all_bindings

          Quota::Enforcer.enforce!

          clients.each do |client|
            verify_connection_not_killed(client)
          end
        end
      end

      context 'and the catalog has a plan that has been removed' do
        before do
          service = Service.build(
            'id' => SecureRandom.uuid,
            'name' => 'our service',
            'description' => 'our service',
            'plans' => [plan1, plan3]
          )

          Catalog.stub(:services) { [service] }
          Quota::Enforcer.update_quotas
        end

        it 'does not kill existing connections' do
          clients = generate_clients_and_connections_for_all_bindings

          Quota::Enforcer.enforce!

          clients.each do |client|
            verify_connection_not_killed(client)
          end
        end
      end

      context 'and the catalog has a plan where the quota has been changed' do
        before do
          plan1 = {
            'id' => 'plan-1-guid',
            'name' => 'plan-1',
            'description' => 'plan-1-desc',
            'max_storage_mb' => -5
          }

          service = Service.build(
            'id' => SecureRandom.uuid,
            'name' => 'our service',
            'description' => 'our service',
            'plans' => [plan1, plan2, plan3]
          )

          Catalog.stub(:services) { [service] }
          Quota::Enforcer.update_quotas
        end

        it 'kills existing connections for only the plan that was changed' do
          clients = generate_clients_and_connections_for_all_bindings

          Quota::Enforcer.enforce!

          verify_connection_killed(clients[0])
          verify_connection_not_killed(clients[1])
        end
      end
    end
  end
end
