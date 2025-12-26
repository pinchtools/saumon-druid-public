# frozen_string_literal: true

module Agent::Configurable
  extend ActiveSupport::Concern

  class Result
    attr_reader :agent, :agent_changed, :version_changed

    def initialize(agent:, agent_changed:, version_changed:)
      @agent = agent
      @agent_changed = agent_changed
      @version_changed = version_changed
    end

    def agent_changed? = @agent_changed
    def version_changed? = @version_changed
    def success? = true
  end

  class_methods do
    def configure_from_yaml(raw_yaml)
      validator = Agents::YamlValidatorService.new(raw_yaml)
      yaml = validator.valid_params.to_h.with_indifferent_access

      agent = find_or_initialize_by_name(yaml["name"])
      agent.configure_with(yaml)
    end

    private

    def find_or_initialize_by_name(name)
      with_name(name).first || new(name: name)
    end
  end

  def configure_with(yaml)
    @configuration_yaml = yaml

    update!(description: yaml["description"])

    current_version = current_agent_version || agent_versions.new
    current_version.assign_attributes(version_attributes)

    return success_result unless current_version.changed? || model_list_changed?

    upgrade_version(current_version)
    upgrade_model_list if model_list_changed?

    success_result
  end

  private

  def upgrade_version(version)
    transaction do
      new_version = if version.new_record?
                      version.tap(&:save!)
      else
                      agent_versions.create!(version_attributes)
      end

      update!(current_agent_version: new_version)
    end
  end

  def upgrade_model_list
    current_agent_version.agent_version_llm_models.destroy_all

    @configuration_yaml["models"].each_with_index do |external_id, index|
      model = LlmModel.find_by_external_id!(external_id)
      current_agent_version.agent_version_llm_models.create!(
        llm_model: model,
        priority: index + 1
      )
    end
  end

  def model_list_changed?
    return true if current_agent_version.nil?

    current_agent_version.enabled_llm_models.pluck(:external_id) != @configuration_yaml["models"]
  end

  def version_attributes
    {
      instructions: build_instructions,
      hyperparams: @configuration_yaml["hyperparams"],
      tools: @configuration_yaml["tools"] || []
    }
  end

  def build_instructions
    Agents::InstructionBuilder.new(@configuration_yaml).to_s
  end

  def success_result
    Result.new(
      agent: self,
      agent_changed: saved_changes?,
      version_changed: current_agent_version&.saved_changes? || false
    )
  end
end
