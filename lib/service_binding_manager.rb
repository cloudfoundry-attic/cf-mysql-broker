class ServiceBindingManager
  def self.create(opts)
    id = opts[:id]
    service_instance = opts[:service_instance]

    binding = ServiceBinding.new(id: id, service_instance: service_instance)
    binding.save

    # ReadOnlyUserRecords.create(binding.username)

    binding
  end

  # def self.create
  # end
end
