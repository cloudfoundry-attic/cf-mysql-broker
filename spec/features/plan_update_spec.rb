require 'spec_helper'

describe 'Plan Upgrade' do

  let(:instance_id_0) { SecureRandom.uuid }
  let(:binding_id_0) { SecureRandom.uuid }
  let(:plan_0) { Settings.services[0].plans[0] }
  let(:plan_1) { Settings.services[0].plans[1] }
  let(:max_storage_mb_0) { plan_0.max_storage_mb.to_i }
  let(:max_storage_mb_1) { plan_1.max_storage_mb.to_i }

  after do
    delete "/v2/service_instances/#{instance_id_0}/service_bindings/#{binding_id_0}"
    delete "/v2/service_instances/#{instance_id_0}"
  end

  specify 'User violates and recovers from quota limit' do
    put "/v2/service_instances/#{instance_id_0}", {plan_id: plan_0.id}
    put "/v2/service_instances/#{instance_id_0}/service_bindings/#{binding_id_0}"
    binding_0 = JSON.parse(response.body)
    credentials_0 = binding_0.fetch('credentials')

    # Fill db past the limit of plan 0
    client_0 = create_mysql_client(credentials_0)
    create_table_and_write_data(client_0, max_storage_mb_0)

    recalculate_usage(instance_id_0)
    enforce_quota
    verify_connection_terminated(client_0)

    # Verify that we cannot write
    client_0 = create_mysql_client(credentials_0)
    verify_write_privileges_revoked(client_0)

    # Change instance to plan 1
    patch "/v2/service_instances/#{instance_id_0}", { plan_id: plan_1.id, previous_values: {} }

    recalculate_usage(instance_id_0)
    enforce_quota
    verify_connection_terminated(client_0)

    # Verify that we can write
    client_0 = create_mysql_client(credentials_0)
    verify_write_privileges_restored(client_0)

    # Fill db past the limit of plan 1
    create_table_and_write_data(client_0, max_storage_mb_1)

    recalculate_usage(instance_id_0)
    enforce_quota
    verify_connection_terminated(client_0)

    # Verify that we cannot write
    client_0 = create_mysql_client(credentials_0)
    verify_write_privileges_revoked(client_0)
  end
end
