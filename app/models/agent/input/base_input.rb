class Agent::Input::BaseInput
  include ActiveModel::Model
  include ActiveModel::Validations
  include ActiveModel::Attributes

  attribute :trace_id, :string
  attribute :message_id, :string

  validates :trace_id, presence: true
  validates :message_id, presence: true
end
