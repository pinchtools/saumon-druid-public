require "httparty"

class SaumonNet::Client
  include HTTParty

  attr_reader :configuration

  def initialize(config = nil)
    @configuration = config || SaumonNet.configuration

    unless @configuration.valid?
      raise SaumonNet::ConfigurationError, "API token is required. Configure it with SaumonNet.configure { |c| c.api_token = 'your_token' }"
    end

    self.class.base_uri(@configuration.base_url)
    self.class.default_timeout(@configuration.timeout)

    if @configuration.debug
      self.class.debug_output($stdout)
    end
  end

  def get(path, options = {})
    response = with_error_handling do
      self.class.get(path, build_options(options))
    end

    parse_response(response)
  end

  private

  def default_headers
    {
      "Authorization" => "Bearer #{@configuration.api_token}",
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end

  def build_options(options)
    {
      headers: default_headers.merge(options[:headers] || {}),
      query: options[:query] || {}
    }
  end

  def with_error_handling
    retries = @configuration.retries

    begin
      response = yield
      handle_response_errors(response)
      response
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => e
      retries -= 1
      if retries > 0
        sleep(1)
        retry
      else
        raise SaumonNet::HttpError, "Request timeout: #{e.message}"
      end
    rescue SocketError => e
      raise SaumonNet::HttpError, "Connection error: #{e.message}"
    end
  end

  def handle_response_errors(response)
    case response.code
    when 200..299
      # Success - do nothing
    when 401
      raise SaumonNet::AuthenticationError, parse_error_message(response)
    when 404
      raise SaumonNet::NotFoundError, parse_error_message(response)
    when 400..499
      raise SaumonNet::ClientError, parse_error_message(response)
    when 500..599
      raise SaumonNet::ServerError, parse_error_message(response)
    else
      raise SaumonNet::HttpError, "Unexpected response code: #{response.code}"
    end
  end

  def parse_error_message(response)
    parsed = parse_response(response)
    parsed.dig("error") || "HTTP #{response.code}"
  rescue
    "HTTP #{response.code}"
  end

  def parse_response(response)
    return {} if response.body.nil? || response.body.empty?

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise SaumonNet::HttpError, "Invalid JSON response: #{e.message}"
  end
end
