class SaumonNet::Configuration
  attr_accessor :base_url, :api_token, :timeout, :retries, :debug

  def initialize
    @base_url = "http://localhost:3004"
    @api_token = nil
    @timeout = 30
    @retries = 3
    @debug = false
  end

  def valid?
    !api_token.nil? && !api_token.empty?
  end
end
