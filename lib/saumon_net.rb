module SaumonNet
  autoload :Client, "saumon_net/client"
  autoload :Configuration, "saumon_net/configuration"
  autoload :Entities, "saumon_net/entities"

  # Base error class for all SaumonNet errors
  class Error < StandardError; end

  # HTTP related errors
  class HttpError < Error; end
  class AuthenticationError < HttpError; end
  class NotFoundError < HttpError; end
  class ClientError < HttpError; end
  class ServerError < HttpError; end

  # Configuration related errors
  class ConfigurationError < Error; end

  class << self
    def configure
      yield(configuration)
      # Reset default clients when configuration changes
      Entity.reset_default_client!
    end

    def configuration
      @configuration ||= Configuration.new
    end
  end
end
