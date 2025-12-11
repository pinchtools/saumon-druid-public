module SaumonNet::TermAttributeExtractor
  extend self

  def extract_origin(mandate_data)
    return nil unless parliamentary_mandate?(mandate_data)

    mandate_data.dig("election", "causeMandat")
  end

  def extract_end_reason(mandate_data)
    return nil unless parliamentary_mandate?(mandate_data)

    mandate_data.dig("mandature", "causeFin")
  end

  def extract_seat_info(mandate_data)
    mandate_data.dig("mandature", "placeHemicycle")
  end

  def extract_assumption_date(mandate_data)
    return nil unless parliamentary_mandate?(mandate_data)

    mandate_data.dig("mandature", "datePriseFonction")
  end

  def extract_collaborators(mandate_data)
    collaborateurs_data = mandate_data["collaborateurs"]
    return [] unless collaborateurs_data.present?

    collaborateur_entries = normalize_to_array(collaborateurs_data["collaborateur"])

    collaborateur_entries.filter_map do |collaborateur|
      next unless collaborateur.is_a?(Hash)

      build_collaborator_name(collaborateur)
    end
  end

  private

  def parliamentary_mandate?(mandate_data)
    mandate_data["@xsi:type"] == "MandatParlementaire_type"
  end

  def normalize_to_array(entries)
    return [] unless entries.present?

    entries.is_a?(Array) ? entries : [ entries ]
  end

  def build_collaborator_name(collaborateur)
    parts = [
      collaborateur["qualite"],
      collaborateur["prenom"],
      collaborateur["nom"]
    ].compact.reject(&:blank?)

    parts.join(" ").strip.presence
  end
end
