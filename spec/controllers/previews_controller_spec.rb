require 'spec_helper'

describe V2::PreviewsController do
  describe '#show' do
    it 'returns a 400' do
      get :show

      expect(response.code).to eq("400")
    end

    context 'when Rails.env is development' do
      before do
        Rails.stub(env: ActiveSupport::StringInquirer.new("development"))
      end

      it 'renders a view that helps developers make CSS/HTML changes' do
        get :show

        expect(response).to render_template 'manage/instances/show'
      end
    end
  end
end
