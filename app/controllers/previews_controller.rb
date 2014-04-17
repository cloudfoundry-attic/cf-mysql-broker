class PreviewsController < ApplicationController
  before_filter :restrict_to_development

  def show
    @quota = 100
    @used_data = 101

    @over_quota = @used_data > @quota

    render 'manage/instances/show'
  end

  private

  def restrict_to_development
    head(:bad_request) unless Rails.env.development?
  end
end
