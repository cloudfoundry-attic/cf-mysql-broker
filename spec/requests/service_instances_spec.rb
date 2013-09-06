require 'spec_helper'

describe 'POST /v2/service_instances' do
  it 'returns the new service instance' do
    post '/v2/service_instances', {reference_id: '42'}, env

    expect(response.status).to eq(201)
    instance = JSON.parse(response.body)

    expect(instance.fetch('id')).to eq('42')
  end
end
