class Agents::Inputs::QueryPlannerV2Input < Agents::Inputs::BaseInput
  attribute :question, :string
  attribute :trace_id, :string
  attribute :message_id, :string

  validates :question, presence: true, length: { minimum: 5, maximum: 500 }
end
