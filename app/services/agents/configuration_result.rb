class Agents::ConfigurationResult
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
