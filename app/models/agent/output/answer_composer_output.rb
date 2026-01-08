# frozen_string_literal: true

class Agent::Output::AnswerComposerOutput < Agent::Output::BaseOutput
  attribute :answer, :string
  attribute :confidence_note, :string

  validates :answer, presence: { message: ->(_object, _data) { I18n.t("agents.answer_composer.errors.answer_required") } }
  validates :answer, length: { minimum: 10, maximum: 5000 }, allow_blank: true
end
