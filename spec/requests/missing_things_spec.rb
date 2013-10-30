require 'spec_helper'

# Behavior when calling endpoints associated with things that do not exist.

describe 'endpoints' do
  describe 'deleting an instance' do
    context 'when the service instance does not exist' do
      it 'returns 410' do
        delete '/v2/service_instances/DOESNOTEXIST'
        expect(response.status).to eq(410)
      end
    end
  end

  describe 'deleting a service binding' do
    context 'when the service binding does not exist' do
      it 'returns 410' do
        delete '/v2/service_instances/service_instance_id/service_bindings/DOESNOTEXIST'
        expect(response.status).to eq(410)
      end
    end
  end
end
