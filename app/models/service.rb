class Service
  attr_reader :id, :name, :description, :tags, :metadata, :plans, :dashboard_client, :plan_updateable

  def self.build(attrs)
    plan_attrs = attrs['plans'] || []
    plans      = plan_attrs.map { |attr| Plan.build(attr) }
    new(attrs.merge('plans' => plans))
  end

  def initialize(attrs)
    @id          = attrs.fetch('id')
    @name        = attrs.fetch('name')
    @description = attrs.fetch('description')
    @plan_updateable = attrs.fetch('plan_updateable', false)
    @tags        = attrs.fetch('tags', [])
    @metadata    = attrs.fetch('metadata', nil)
    @plans       = attrs.fetch('plans', [])
    @dashboard_client = attrs.fetch('dashboard_client', {})
  end

  def bindable?
    true
  end

  def to_hash
    {
      'id'               => id,
      'name'             => name,
      'description'      => description,
      'tags'             => tags,
      'metadata'         => metadata,
      'plan_updateable'  => plan_updateable,
      'plans'            => plans.map(&:to_hash),
      'bindable'         => bindable?,
      'dashboard_client' => dashboard_client
    }
  end
end
