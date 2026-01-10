require "sidekiq/middleware/current_attributes"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_SIDEKIQ_URL", "redis://redis:6379/1") }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_SIDEKIQ_URL", "redis://redis:6379/1") }
end

# Persist CurrentAttributes from web request to Sidekiq job
Sidekiq::CurrentAttributes.persist("Current")
