class AgentVersionLlmModel < ApplicationRecord
  belongs_to :agent_version
  belongs_to :llm_model

  validates :agent_version, presence: true
  validates :llm_model, presence: true, uniqueness: { scope: :agent_version_id }
  validates :priority, presence: true, numericality: { only_integer: true }, uniqueness: { scope: :agent_version_id }
  validates :enabled, inclusion: { in: [ true, false ] }

  scope :enabled, -> { where(enabled: true) }
  scope :by_priority, -> { order(priority: :asc) }
end
