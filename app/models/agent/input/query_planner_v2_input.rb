class Agent::Input::QueryPlannerV2Input < Agent::Input::BaseInput
  attribute :question, :string

  validates :question, presence: true, length: { minimum: 5, maximum: 500 }
end
