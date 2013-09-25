require 'securerandom'
require 'digest/md5'

class UserCreds
  attr_reader :username, :password

  def initialize(binding_id)
    # mysql usernames are limited to 16 chars
    @username = Digest::MD5.base64digest(binding_id)[0...16]
    @password = SecureRandom.hex(8)
  end
end

