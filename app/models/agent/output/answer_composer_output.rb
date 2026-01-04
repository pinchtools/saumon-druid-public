# frozen_string_literal: true

class Agent::Output::AnswerComposerOutput < Agent::Output::BaseOutput
  attribute :answer, :string
  attribute :sources, array: true, default: []
  attribute :confidence_note, :string

  validates :answer, presence: { message: ->(_object, _data) { I18n.t("agents.answer_composer.errors.answer_required") } }
  validates :answer, length: { minimum: 10, maximum: 5000 }, allow_blank: true
  validate :validate_sources_structure

  private

  def validate_sources_structure
    return if sources.blank?
    return add_sources_type_error unless sources.is_a?(Array)

    validate_sources_items
  end

  def add_sources_type_error
    errors.add(:sources, I18n.t("agents.answer_composer.errors.sources_must_be_array"))
  end

  def validate_sources_items
    sources.each_with_index do |source, index|
      next if source.is_a?(String)

      errors.add(:sources, I18n.t("agents.answer_composer.errors.source_item_must_be_string", index: index + 1))
    end
  end
end
