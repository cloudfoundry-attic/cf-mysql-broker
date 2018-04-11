class V2::ServiceBindingsController < V2::BaseController
  ALLOWED_BINDING_PARAMETERS = ['read-only']

  def update
    instance = ServiceInstance.find_by_guid(params.fetch(:service_instance_id))
    if instance.nil?
      render status: 404, json: {}
      return
    end

    binding_parameters = params.fetch(:parameters, {})
    binding_parameters_include_unknown_key = binding_parameters.keys.any? {|key| !ALLOWED_BINDING_PARAMETERS.include?(key)}

    read_only = binding_parameters.fetch('read-only', false)
    read_only_parameter_has_invalid_value = !read_only.in?([true, false])

    if binding_parameters_include_unknown_key || read_only_parameter_has_invalid_value
      render status: 400, json: {
        "error" => "Error creating service binding",
        "description" => "Invalid arbitrary parameter syntax. Please check the documentation for supported arbitrary parameters.",
      }
      return
    end

    binding = ServiceBinding.new(id: params.fetch(:id), service_instance: instance, read_only: read_only)
    binding.save

    render status: 201, json: binding
  end

  def destroy
    binding = ServiceBinding.find_by_id(params.fetch(:id))
    if binding
      binding.destroy
      status = 200
    else
      status = 410
    end

    render status: status, json: {}
  end
end
