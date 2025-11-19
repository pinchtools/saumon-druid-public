class Agents::BaseAgent
  attr_reader :agent, :current_version, :enabled_models

  delegate :agent_name, to: :class

  def initialize
    @agent = Agent.with_name(agent_name).active.first
    raise ArgumentError, "Agent '#{agent_name}' not found or inactive" unless @agent

    @current_version = @agent.current_agent_version
    raise ArgumentError, "Agent '#{agent_name}' has no current version" unless @current_version

    @enabled_models = @current_version.enabled_llm_models
    raise ArgumentError, "Agent '#{agent_name}' has no enabled models" unless @enabled_models.any?
  end

  def name
    @agent.name
  end

  def normalized_name
    @agent.normalized_name
  end

  def version
    @current_version.version
  end

  def primary_model
    @enabled_models.first
  end

  protected

  def self.agent_name(name = nil)
    return @agent_name if @agent_name

    if name
      @agent_name = name.to_s
    else
      @agent_name || self.name.demodulize.underscore
    end
  end
end
