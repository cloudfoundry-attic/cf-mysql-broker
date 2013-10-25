class Service
  attr_reader :id, :name, :description, :tags, :metadata, :plans

  def self.build(attrs)
    plan_attrs = attrs.fetch('plans')
    plans      = plan_attrs.map { |attr| Plan.build(attr) }
    new(attrs.merge('plans' => plans))
  end

  def initialize(attrs)
    @id          = attrs.fetch('id')
    @name        = attrs.fetch('name')
    @description = attrs.fetch('description')
    @tags        = attrs.fetch('tags', [])
    @metadata    = attrs.fetch('metadata', nil)
    @plans       = attrs.fetch('plans', [])
  end

  def bindable?
    true
  end

  def to_hash
    {
      'id'          => self.id,
      'name'        => self.name,
      'description' => self.description,
      'tags'        => self.tags,
      'metadata'    => self.metadata,
      'plans'       => self.plans.map(&:to_hash),
      'bindable'    => self.bindable?
    }
  end

end