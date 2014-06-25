class ServiceCapacity
  def self.can_allocate?(new_db_storage_mb)
    ServiceInstance.reserved_space_in_mb + new_db_storage_mb <= Settings['storage_capacity_mb']
  end
end
