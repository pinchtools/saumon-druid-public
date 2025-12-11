class Llm::ImporterService
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
    Llm::ModelImporter.new(model_config).call
  end
end
