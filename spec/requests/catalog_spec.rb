require 'spec_helper'

describe 'GET /v2/catalog' do
  it 'returns the catalog of services' do
    get '/v2/catalog'

    expect(response.status).to eq(200)
    catalog = JSON.parse(response.body)
    service_settings = YAML.load_file(Rails.root + 'config/settings.yml').fetch('test').fetch('services').first

    services = catalog.fetch('services')
    expect(services).to have(1).service

    service = services.first
    expect(service.fetch('name')).to eq(service_settings.fetch('name'))
    expect(service.fetch('description')).to eq(service_settings.fetch('description'))
    expect(service.fetch('bindable')).to be_true
    expect(service.fetch('metadata')).to eq(service_settings.fetch('metadata'))

    plans = service.fetch('plans')
    expect(plans).to have(2).plan

    plan = plans.first
    plan_settings = service_settings.fetch('plans').first
    expect(plan.fetch('name')).to eq(plan_settings.fetch('name'))
    expect(plan.fetch('description')).to eq(plan_settings.fetch('description'))
    expect(plan.fetch('metadata')).to eq(plan_settings.fetch('metadata'))

    plan = plans[1]
    plan_settings = service_settings.fetch('plans')[1]
    expect(plan.fetch('name')).to eq(plan_settings.fetch('name'))
    expect(plan.fetch('description')).to eq(plan_settings.fetch('description'))
    expect(plan.fetch('metadata')).to eq(plan_settings.fetch('metadata'))
  end
end
