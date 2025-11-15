class AgentVersion < ApplicationRecord
  belongs_to :agent

  validates :agent_id, presence: true
  validates :version, presence: true, uniqueness: { scope: :agent_id }
end
