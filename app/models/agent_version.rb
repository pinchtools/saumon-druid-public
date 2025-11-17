class AgentVersion < ApplicationRecord
  belongs_to :agent
  has_many :agent_version_llm_models, dependent: :destroy
  has_many :llm_models, through: :agent_version_llm_models

  has_many :enabled_agent_version_llm_models, -> { enabled }, class_name: "AgentVersionLlmModel"
  has_many :enabled_llm_models, through: :enabled_agent_version_llm_models, source: :llm_model

  validates :agent_id, presence: true
  validates :version, presence: true, uniqueness: { scope: :agent_id }
  before_validation :set_version, on: :create

  def set_version
    return if agent.nil?

    self.version = (agent.agent_versions.maximum(:version) || 0) + 1
  end
end
