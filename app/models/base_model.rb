class BaseModel
  include ActiveModel::Model

  private

  def self.connection
    ActiveRecord::Base.connection
  end

  def connection
    self.class.connection
  end
end
