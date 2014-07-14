class ServiceCapacity
  def self.can_allocate?(new_db_storage_mb)
    current_size_reserved + ServiceInstance.reserved_space_in_mb + new_db_storage_mb <= Settings['persistent_disk']
  end

  private

  def self.current_size_reserved
    #constant overhead on initialize of cluster values are in MB
    ibdata_file_size = 12
    broker_db_size = 0.26
    gcache_size = Settings['gcache_size']
    mysql_db_size = 1.2
    performance_db_size = 0.22

    #while innodb_log_per_table true??
    ib_log_file_size = 2 * Settings['ib_log_file_size']

    current_db_overhead = (0.008 + 0.064 + 0.001) * ServiceInstance.all.count
    current_binding_overhead = 0.0008 * ServiceBinding.count

    #can edit, for the sake of safety currently & undeleted GRA_*.logs
    buffer= 50

    return ibdata_file_size + broker_db_size + gcache_size +
        mysql_db_size + performance_db_size + ib_log_file_size +
        current_db_overhead + current_binding_overhead + buffer
  end
end
