class Agents::SynchronisationService
  def call
    path = Rails.root.join("config/agents/*.yml")

    Dir[path].each do |file|
      yaml = YAML.safe_load_file(file, permitted_classes: [ Symbol ])

      Agent.configure_from_yaml(yaml)
    end
  end
end
