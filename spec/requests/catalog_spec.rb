require 'spec_helper'

describe 'GET /v2/catalog' do
  it 'returns the catalog of services' do
    get '/v2/catalog'

    expect(response.status).to eq(200)
    catalog = JSON.parse(response.body)

    services = catalog.fetch('services')
    expect(services).to have(1).service

    service = services.first
    expect(service.fetch('name')).to eq('p-mysql')
    expect(service.fetch('description')).to eq('MySQL service for application development and testing')
    expect(service.fetch('bindable')).to be_true
    expect(service.fetch('metadata')).to eq({})

    plans = service.fetch('plans')
    expect(plans).to have(1).plan

    plan = plans.first
    expect(plan.fetch('name')).to eq('5mb')
    expect(plan.fetch('description')).to eq('Shared MySQL Server, 5mb persistent disk, 40 max concurrent connections')
    expect(plan.fetch('metadata').fetch('bullets')).to eq([
      'Shared MySQL server' ,
      '5 MB storage',
      '40 concurrent connections',
    ])
  end
end
