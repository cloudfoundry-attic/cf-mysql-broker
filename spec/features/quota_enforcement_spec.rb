require 'spec_helper'

describe 'Quota enforcement' do
  let(:instance_id_0) { SecureRandom.uuid }
  let(:binding_id_0) { SecureRandom.uuid }
  let(:max_storage_mb_0) { Settings.services[0].plans[0].max_storage_mb.to_i }

  let(:instance_id_1) { SecureRandom.uuid }
  let(:binding_id_1) { SecureRandom.uuid }
  let(:max_storage_mb_1) { Settings.services[0].plans[1].max_storage_mb.to_i }

  after do
    delete "/v2/service_instances/#{instance_id_0}/service_bindings/#{binding_id_0}"
    delete "/v2/service_instances/#{instance_id_0}"

    delete "/v2/service_instances/#{instance_id_1}/service_bindings/#{binding_id_1}"
    delete "/v2/service_instances/#{instance_id_1}"
  end

  specify 'User violates and recovers from quota limit' do
    put "/v2/service_instances/#{instance_id_0}", {plan_id: Settings.services[0].plans[0].id}
    put "/v2/service_instances/#{instance_id_0}/service_bindings/#{binding_id_0}"
    binding_0 = JSON.parse(response.body)
    credentials_0 = binding_0.fetch('credentials')

    put "/v2/service_instances/#{instance_id_1}", {plan_id: Settings.services[0].plans[1].id}
    put "/v2/service_instances/#{instance_id_1}/service_bindings/#{binding_id_1}"
    binding_1 = JSON.parse(response.body)
    credentials_1 = binding_1.fetch('credentials')

    client_0 = create_mysql_client(credentials_0)
    client_1 = create_mysql_client(credentials_1)
    create_table_and_write_data(client_0, max_storage_mb_0)
    create_table_and_write_data(client_1, max_storage_mb_1)
    recalculate_usage(instance_id_0)
    recalculate_usage(instance_id_1)

    enforce_quota

    verify_connection_terminated(client_0)
    verify_connection_terminated(client_1)

    client_0 = create_mysql_client(credentials_0)
    client_1 = create_mysql_client(credentials_1)
    verify_write_privileges_revoked(client_0)
    verify_write_privileges_revoked(client_1)
    prune_database(client_0)
    prune_database(client_1)
    recalculate_usage(instance_id_0)
    recalculate_usage(instance_id_1)

    enforce_quota

    verify_connection_terminated(client_0)
    verify_connection_terminated(client_1)

    client_0 = create_mysql_client(credentials_0)
    client_1 = create_mysql_client(credentials_1)
    verify_write_privileges_restored(client_0)
    verify_write_privileges_restored(client_1)
  end
end
