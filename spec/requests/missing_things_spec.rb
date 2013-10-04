require 'spec_helper'

# Behavior when calling endpoints associated with things that do not exist.

describe 'endpoints' do

  context 'id does not exist' do
    describe 'deleting an instance' do
      it 'returns 410' do
        delete '/v2/service_instances/DOESNOTEXIST', {format: :json}, env
        expect(response.status).to eq(410)
      end
    end

    describe 'deleting a binding' do
      it 'returns 410' do
        delete '/v2/service_bindings/DOESNOTEXIST', {format: :json}, env
        expect(response.status).to eq(410)
      end
    end
  end
end
