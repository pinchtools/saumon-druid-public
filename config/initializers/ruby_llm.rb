RubyLLM.configure do |config|
  config.openrouter_api_key = ENV["OPENROUTER_API_KEY"] || Rails.application.credentials.dig(:openai_api_key)

  config.default_model = ENV["AGENTIC_PRIMARY_MODEL"] || "mistralai/ministral-3b"
  config.default_embedding_model = "text-embedding-3-large"

  config.request_timeout = 15
  config.max_retries = 2
  config.retry_interval = 1

  config.log_level = Rails.env.development? ? :debug : :info
  config.log_stream_debug = Rails.env.development?

  config.use_new_acts_as = true

  config.model_registry_file = Rails.root.join("tmp", "ruby_llm_models.json")
end

RubyLLM.models.refresh!
RubyLLM.models.save_to_json
