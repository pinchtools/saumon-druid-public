# frozen_string_literal: true

module LlmModel::Configurable
  extend ActiveSupport::Concern

  class_methods do
    def configure_from_yaml(model_config)
      ruby_llm_model = fetch_ruby_llm_model(model_config["id"])
      return unless ruby_llm_model

      llm_model = find_or_initialize_by(external_id: ruby_llm_model.id)
      llm_model.configure_with(ruby_llm_model, model_config)
    end

    private

    def fetch_ruby_llm_model(model_id)
      RubyLLM.models.find(model_id)
    rescue RubyLLM::ModelNotFoundError => e
      Rails.logger.error(e.full_message)
      nil
    end
  end

  def configure_with(ruby_llm_model, model_config)
    pricing = extract_pricing(ruby_llm_model)

    update!(
      capabilities: ruby_llm_model.capabilities,
      context_window: ruby_llm_model.context_window,
      family: ruby_llm_model.family,
      free: pricing.nil?,
      input_cost: pricing&.input_per_million,
      knowledge_cutoff: ruby_llm_model.knowledge_cutoff,
      name: ruby_llm_model.name,
      output_cost: pricing&.output_per_million,
      output_size: ruby_llm_model.max_output_tokens,
      provider: ruby_llm_model.provider,
      supported_params: ruby_llm_model.metadata[:supported_parameters],
      tier: model_config["tier"]
    )

    self
  end

  private

  def extract_pricing(ruby_llm_model)
    ruby_llm_model.pricing&.text_tokens&.standard
  end
end
