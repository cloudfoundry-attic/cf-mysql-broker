require 'spec_helper'

describe V2::ServiceInstancesController do
  before { authenticate }

  describe '#create' do
    it 'uses the reference id as the real id' do
      post :create, reference_id: '42'

      expect(response.status).to eq(201)
      instance = JSON.parse(response.body)

      expect(instance['id']).to eq('42')
    end
  end
end
