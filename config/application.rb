require_relative "boot"

require "rails/all"
require_relative "../app/lib/component_logger_formatter"
require_relative "../app/lib/rails_event_logger_subscriber"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SaumonDruid
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.log_formatter = ComponentLoggerFormatter.new

    config.log_file_size = 250.megabytes

    # Register the Rails event logger subscriber
    config.after_initialize do
      Rails.event.subscribe(RailsEventLoggerSubscriber.new)
    end

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
