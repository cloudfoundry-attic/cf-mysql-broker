class ServiceInstance < ActiveRecord::Base
  def self.reserved_space_in_mb
    self.sum(:max_storage_mb)
  end
end
