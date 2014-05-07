class RequestLogger
  attr_reader :logger

  def initialize(logger)
    @logger = logger
  end

  def log_headers_and_body(headers, body)
    request_summary = {
      headers: filtered_request_headers(headers),
      body:    body
    }

    logger.info "Request: #{request_summary.to_json}"
  end

  private

  def filtered_request_headers(headers)
    headers.keys.each do |k|
      headers[k] = '[PRIVATE DATA HIDDEN]' if filtered_keys.include?(k)
    end

    headers.select { |key, _| permitted_keys.include? key }
  end

  def permitted_keys
    %w(CONTENT_LENGTH
        CONTENT_TYPE
        GATEWAY_INTERFACE
        PATH_INFO
        QUERY_STRING
        REMOTE_ADDR
        REMOTE_HOST
        REQUEST_METHOD
        REQUEST_URI
        SCRIPT_NAME
        SERVER_NAME
        SERVER_PORT
        SERVER_PROTOCOL
        SERVER_SOFTWARE
        HTTP_ACCEPT
        HTTP_USER_AGENT
        HTTP_AUTHORIZATION
        HTTP_X_VCAP_REQUEST_ID
        HTTP_X_BROKER_API_VERSION
        HTTP_HOST
        HTTP_VERSION
        REQUEST_PATH)
  end

  def filtered_keys
    %w(HTTP_AUTHORIZATION)
  end
end
