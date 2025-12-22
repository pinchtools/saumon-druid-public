class Llm::ImporterService
  def initialize(yaml_path = nil)
    @yaml_path = yaml_path || Rails.root.join("config", "llms", "models.yml")
  end

  def call
    sync!

    yaml.values.flatten.each do |model_config|
      LlmModel.configure_from_yaml(model_config)
    end

    true
  end

  private

  def yaml
    YAML.safe_load_file(@yaml_path, permitted_classes: [ Symbol ])
  end

  def sync!
    RubyLLM.models.refresh!
  end
end
