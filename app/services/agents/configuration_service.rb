module Agents
  class ConfigurationService
    attr_reader :yaml, :validated_params

    def initialize(raw_yaml)
      validator = YamlValidatorService.new(raw_yaml)
      @validated_params = validator.valid_params
      @yaml = validated_params.to_h.with_indifferent_access
    end

    def call
      agent.update!(agent_attrs)

      agent_version.assign_attributes(agent_version_attrs)

      return success_result unless agent_version.changed? || model_list_changed?

      upgrade_version(agent_version)
      upgrade_model_list(agent.current_agent_version) if model_list_changed?

      success_result
    end

    private

    def upgrade_version(agent_version)
      Agent.transaction do
        new_agent = if agent_version.new_record?
                      agent_version.tap(&:save!)
        else
                      agent.agent_versions.create!(agent_version_attrs)
        end

        agent.update!(current_agent_version: new_agent)
      end
    end

    def upgrade_model_list(agent_version)
      agent_version.agent_version_llm_models.destroy_all

      yaml["models"].each_with_index do |id, priority|
        model = LlmModel.find_by_external_id!(id)
        agent_version.agent_version_llm_models.create!(llm_model: model, priority: priority + 1)
      end
    end

    def model_list_changed?
      return true if agent.current_agent_version.nil?

      agent.current_agent_version.enabled_llm_models.pluck(:external_id) != yaml["models"]
    end

    def agent
      @agent ||= Agent.with_name(yaml["name"]).first || Agent.new(name: yaml["name"])
    end

    def agent_version
      @agent_version ||= agent.current_agent_version || agent.agent_versions.new
    end

    def proceed?
      true if agent.new_record? || agent_version.new_record?
    end

    def agent_attrs
      {
        description: yaml["description"]
      }
    end

    def agent_version_attrs
      {
        instructions: instructions,
        hyperparams: yaml["hyperparams"]
      }
    end

    def instructions
      InstructionBuilder.new(yaml).to_s
    end

    def success_result
      ConfigurationResult.new(
        agent_changed: agent.saved_changes?,
        agent_version_changed: agent_version.changed? || agent_version.saved_changes?
      )
    end
  end

  class ConfigurationResult
    attr_reader :agent_changed, :agent_version_changed

    def initialize(agent_changed:, agent_version_changed:)
      @agent_changed = agent_changed
      @agent_version_changed = agent_version_changed
    end

    def agent_changed?
      @agent_changed
    end

    def agent_version_changed?
      @agent_version_changed
    end

    def success?
      true
    end
  end

  class InstructionBuilder
    attr_reader :yaml

    def initialize(yaml)
      @yaml = yaml
    end

    def to_s
      [ role, directives, context_format ].compact.join("\n\n")
    end

    def role
      yaml["role"]
    end

    def directives
      yaml["directives"]
    end

    def context_format
      return nil unless yaml["context_format"]

      <<~TEXT
        CONTEXT_FORMAT
        ----------
        #{JSON.parse(yaml["context_format"])}
      TEXT
    end
  end
end
