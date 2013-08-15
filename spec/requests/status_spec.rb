require 'spec_helper'

describe 'GET /v3' do
  it 'returns an OK response' do
    get '/v3', {}, env
    expect(response.status).to eq(200)
    expect(response.body).to eq(['OK'].to_json)
  end
end
