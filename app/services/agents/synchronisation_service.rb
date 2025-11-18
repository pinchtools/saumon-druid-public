class Agents::SynchronisationService
  def call
    path = Rails.root.join("config/agents/*.yml")

    Dir[ path ].each do |file|
      yaml = YAML.safe_load_file(file, permitted_classes: [ Symbol ])

      Agents::ConfigurationService.new(yaml).call
    end
  end
end
