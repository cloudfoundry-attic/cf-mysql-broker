require 'spec_helper'

describe V3::StatusesController do
  before { authenticate }

  describe '#show' do
    it 'should return an OK response' do
      get :show
      expect(response.status).to eq(200)
      expect(response.body).to eq(['OK'].to_json)
    end
  end
end
