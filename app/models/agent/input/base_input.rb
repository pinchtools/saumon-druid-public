class Agent::Input::BaseInput
  include ActiveModel::Model
  include ActiveModel::Validations
  include ActiveModel::Attributes

  validates :trace_id, presence: true
  validates :message_id, presence: true
end
