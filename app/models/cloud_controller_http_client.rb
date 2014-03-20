class CloudControllerHttpClient
  attr_reader :cc_url, :auth_header
  def initialize(cc_url, auth_header)
    @cc_url = cc_url
    @auth_header = auth_header
  end

  def get(path)
    uri = URI.parse("#{cc_url.gsub(/\/$/, '')}/#{path.gsub(/^\//, '')}")

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = auth_header

    response = http.request(request)

    JSON.parse(response.body)
  end
end
