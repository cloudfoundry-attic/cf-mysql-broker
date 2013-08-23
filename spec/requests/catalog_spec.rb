require 'spec_helper'

describe 'GET /v2/catalog' do
  it 'returns the catalog of services' do
    get '/v2/catalog', {}, env

    expect(response.status).to eq(200)
    catalog = JSON.parse(response.body)

    services = catalog.fetch('services')
    expect(services).to have(1).service

    service = services.first
    expect(service.fetch('name')).to eq('cf-mysql')
    expect(service.fetch('description')).to eq('Cloud Foundry MySQL')

    plans = service.fetch('plans')
    expect(plans).to have(1).plan

    plan = plans.first
    expect(plan.fetch('name')).to eq('free')
    expect(plan.fetch('description')).to eq('Free Trial')
  end
end
