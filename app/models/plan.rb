class Plan
  attr_reader :id, :name, :description, :metadata, :max_storage_mb, :max_user_connections

  def self.build(attrs)
    new(attrs)
  end

  def initialize(attrs)
    @id          = attrs.fetch('id')
    @name        = attrs.fetch('name')
    @description = attrs.fetch('description')
    @metadata    = attrs.fetch('metadata', nil)
    @max_storage_mb = attrs.fetch('max_storage_mb', nil)
    @max_user_connections = attrs.fetch('max_user_connections', nil)
  end

  def to_hash
    {
      'id'          => self.id,
      'name'        => self.name,
      'description' => self.description,
      'metadata'    => self.metadata,
    }
  end
end
