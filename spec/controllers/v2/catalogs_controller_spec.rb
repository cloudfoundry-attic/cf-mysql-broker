require 'spec_helper'

describe V2::CatalogsController do
  describe '#show' do
    context 'when the basic-auth username is incorrect' do
      before do
        set_basic_auth('wrong_username', Settings.auth_password)
      end

      it 'responds with a 401' do
        get :show

        expect(response.status).to eq(401)
      end
    end

    context 'when the basic-auth credentials are correct' do
      before { authenticate }

      it 'builds services from the values in Settings' do
        service_setting_1_stub = double(:service_setting_1_stub)
        service_setting_2_stub = double(:service_setting_2_stub)
        service_1 = double(:service_1, to_hash: {'service1' => 'to_hash'})
        service_2 = double(:service_1, to_hash: {'service2' => 'to_hash'})
        allow(Settings).to receive(:[]).with('services').
          and_return([service_setting_1_stub, service_setting_2_stub])
        expect(Service).to receive(:build).with(service_setting_1_stub).and_return(service_1)
        expect(Service).to receive(:build).with(service_setting_2_stub).and_return(service_2)

        get :show

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(
          {'services' => [
            {'service1' => 'to_hash'},
            {'service2' => 'to_hash'},
          ]}
        )
      end

      context 'with invalid catalog data' do
        before do
          Settings.stub(:[]).with('services').and_return(nil)
        end

        context 'when there are no services' do
          it 'produces an empty catalog' do
            get :show
            expect(response.status).to eq(200)
            catalog = JSON.parse(response.body)

            services = catalog.fetch('services')
            expect(services).to have(0).services
          end
        end
      end
    end

  end
end
