require 'securerandom'
require 'digest/md5'

class UserCreds
  attr_reader :username, :password

  def initialize(guid)
    # mysql usernames are limited to 16 chars
    @username = Digest::MD5.base64digest(guid)[0...16]
    @password = SecureRandom.hex(8)
  end
end

