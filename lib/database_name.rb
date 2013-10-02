
# Provides a sql-safe database name for the given instance id.
# If you change the logic of this method, make sure not to allow
# sql injection attacks.

class DatabaseName
  attr_reader :name

  def initialize(instance_id)
    if instance_id.match(/[^0-9,a-z,A-Z$-]+/)
      raise 'Only ids matching [0-9,a-z,A-Z$-]+ are allowed'
    end

    # mysql database names are limited to [0-9,a-z,A-Z$_] and 64 chars
    @name = instance_id.gsub('-', '_').downcase
  end
end

