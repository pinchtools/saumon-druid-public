# frozen_string_literal: true

class Agent::Input::AnswerComposerInput < Agent::Input::BaseInput
  attribute :question, :string
  attribute :results, default: {}
  attribute :confidence, :integer

  validates :question, presence: true, length: { minimum: 1, maximum: 1000 }
  validates :results, presence: true
  validates :confidence, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true
end
