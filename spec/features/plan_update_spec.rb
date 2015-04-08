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

  specify 'User updates to a plan with a larger quota' do
    put "/v2/service_instances/#{instance_id_0}", {plan_id: plan_0.id}
    put "/v2/service_instances/#{instance_id_0}/service_bindings/#{binding_id_0}"
    binding_0 = JSON.parse(response.body)
    credentials_0 = binding_0.fetch('credentials')

    # Fill db past the limit of plan 0
    client_0 = create_mysql_client(credentials_0)
    create_table_and_write_data(client_0, max_storage_mb_0)

    # Change instance to plan 1
    patch "/v2/service_instances/#{instance_id_0}", { plan_id: plan_1.id, previous_values: {} }
    expect(response.status).to eq 200

    # Verify that we can write
    client_0 = create_mysql_client(credentials_0)
    verify_client_can_write(client_0)
  end

  specify 'User tries to downgrade to a plan with a smaller quota than he is currently using' do
    # Create db with larger quota
    put "/v2/service_instances/#{instance_id_0}", {plan_id: plan_1.id}
    put "/v2/service_instances/#{instance_id_0}/service_bindings/#{binding_id_0}"
    binding_0 = JSON.parse(response.body)
    credentials_0 = binding_0.fetch('credentials')

    # Fill db past limit of plan 0
    client_0 = create_mysql_client(credentials_0)
    create_table_and_write_data(client_0, max_storage_mb_0 + 1)

    # Attempt to change instance to plan 0
    patch "/v2/service_instances/#{instance_id_0}", { plan_id: plan_0.id, previous_values: {} }
    expect(response.status).to eq 422
  end
end
