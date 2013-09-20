require 'spec_helper'

describe 'POST /v2/service_instances' do
  it 'returns the new service instance' do
    put '/v2/service_instances/42', {service_plan_id: '123'}, env

    expect(response.status).to eq(201)
    instance = JSON.parse(response.body)

    expect(instance.fetch('dashboard_url')).to eq('http://fake.dashboard.url')
  end
end
