unless Rails.env.test?

  register_thread = Thread.new do
    NATS.start(:uri => Settings.message_bus_servers) do
      registrar.register_with_router
    end
  end

  Kernel.at_exit do
    register_thread.kill
    register_thread.join

    NATS.start(:uri => Settings.message_bus_servers) do
      registrar.shutdown { EM.stop }
    end
  end

  def registrar
    Cf::Registrar.new(
      :message_bus_servers => Settings.message_bus_servers,
      :host                => Settings.external_ip,
      :port                => 80,
      :uri                 => Settings.external_host,
      :tags                => { "component" => "P-MySQL" })
  end

end
