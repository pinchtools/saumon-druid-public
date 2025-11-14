module Llm
  class ImporterService
    def initialize(yaml_path = nil)
      @yaml_path = yaml_path || Rails.root.join("config", "llms", "models.yml")
    end

    def call
      sync!

      yaml.values.flatten.each(&method(:import_model))

      true
    end

    private

    def yaml
      YAML.safe_load_file(@yaml_path, permitted_classes: [ Symbol ])
    end

    def sync!
      RubyLLM.models.refresh!
    end

    def import_model(model_config)
      ModelImporter.new(model_config).call
    end
  end

  class ModelImporter
    include ActiveSupport::Rescuable

    attr_reader :model_config

    rescue_from(RubyLLM::ModelNotFoundError) do |error|
      Rails.logger.error(error.full_message)
      nil
    end

    def initialize(model_config)
      @model_config = model_config
    end

    def call
      return unless ruby_llm_model

      llm_model = LlmModel.find_or_initialize_by(external_id: ruby_llm_model.id)

      llm_model.update!(capabilities: ruby_llm_model.capabilities,
                        context_window: ruby_llm_model.context_window,
                        family: ruby_llm_model.family,
                        free: !pricing?,
                        input_cost: input_cost,
                        knowledge_cutoff: ruby_llm_model.knowledge_cutoff,
                        name: ruby_llm_model.name,
                        output_cost: output_cost,
                        output_size: ruby_llm_model.max_output_tokens,
                        provider: ruby_llm_model.provider,
                        supported_params: ruby_llm_model.metadata[:supported_parameters],
                        tier: model_config["tier"]
      )
      llm_model
    end

    private

    def ruby_llm_model
      @ruby_llm_model ||= RubyLLM.models.find(model_config["id"])
    rescue => e
      rescue_with_handler(e) || raise
      nil
    end

    def pricing?
      @has_pricing ||= standard_pricing.present?
    end

    def pricing
      @pricing ||= ruby_llm_model.pricing.try(:text_tokens)
    end

    def standard_pricing
      @standard_pricing ||= pricing.try(:standard)
    end

    def output_cost
      return unless standard_pricing

      standard_pricing.try(:output_per_million)
    end

    def input_cost
      return unless standard_pricing

      standard_pricing.try(:input_per_million)
    end
  end
end
