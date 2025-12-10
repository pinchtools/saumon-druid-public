module An::Stakeholder::SearchContentBuilder
  extend ActiveSupport::Concern

  def fts_search_content
    [
      name.parameterize(separator: " "),
      2.times.map { current_top_position&.label }.compact,
      other_top_active_positions.map(&:label).join(" "),
      top_past_positions.map(&:label).join(" "),
      occupation&.parameterize(separator: " ")
    ].flatten.compact.join("\n")
  end

  def trigram_search_content
    [
      name.parameterize(separator: " "),
      current_top_position&.label,
      other_top_active_positions.map(&:label).join(" "),
      top_past_positions.map(&:label).join(" "),
      occupation&.parameterize(separator: " ")
    ].flatten.compact.join("\n")
  end

  def vector_search_content
    [
      build_vector_name_section,
      build_vector_top_active_position_section || build_vector_top_past_position_section
    ].compact.join("\n\n")
  end

  private

  def build_vector_name_section
    I18n.t("an.stakeholder.vector_search.name", name: name)
  end

  def build_vector_top_active_position_section
    main_term = an_terms.active.by_hierarchy&.first

    return unless main_term

    [
      I18n.t("an.stakeholder.vector_search.main_position", position: main_term.capacity.humanize),
      *format_vector_term_details(main_term)
    ].join("\n")
  end

  def build_vector_top_past_position_section
    term = an_terms.past.by_hierarchy.first

    return unless term
    [
      I18n.t("an.stakeholder.vector_search.old_top_position", position: term.capacity.humanize),
      *format_vector_term_details(term)
    ].join("\n")
  end

  def format_vector_term_details(term)
    [
      I18n.t("an.stakeholder.vector_search.liability_level", rank: term.role_rank_label),
      I18n.t("an.stakeholder.vector_search.role", role: term.label),
      I18n.t("an.stakeholder.vector_search.institution",
             institution: An::BodyType.humanize("codes.#{term.an_body.an_body_type.code}", default: nil))
    ].compact
  end
end
