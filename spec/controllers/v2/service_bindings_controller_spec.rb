require 'spec_helper'

describe V2::ServiceBindingsController do
  before { authenticate }

  describe '#create' do
    it 'sends back credentials' do
      put :create, id: '42'

      expect(response.status).to eq(201)
      instance = JSON.parse(response.body)

      expect(instance['credentials']).to eq('{ "foo": "bar" }')
    end
  end
end
