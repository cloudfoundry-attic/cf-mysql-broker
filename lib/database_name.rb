
class DatabaseName
  attr_reader :name

  def initialize(instance_id)
    # mysql database names are limited to [0-9,a-z,A-Z$_] and 64 chars
    @name = instance_id.gsub('-', '_')
  end
end

