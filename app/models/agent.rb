class Agent < ApplicationRecord
  belongs_to :current_agent_version, class_name: "AgentVersion", optional: true
  has_many :agent_versions

  before_validation :normalize_name

  validates :name, presence: true
  validates :normalized_name, presence: true, uniqueness: true

  validate :current_version_owned_by_agent

  private

  def normalize_name
    self.normalized_name = name.downcase.gsub(/[^a-z0-9_]/, "_") if name
  end
  def current_version_owned_by_agent
    if current_agent_version.present?
      errors.add(:current_agent_version, "does not belong to agent") unless current_agent_version.agent_id == id
    end
  end
end
