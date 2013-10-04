module ModelHelpers
  def connection
    ActiveRecord::Base.connection
  end
end

RSpec.configure do |config|
  config.include ModelHelpers, type: :model
end
