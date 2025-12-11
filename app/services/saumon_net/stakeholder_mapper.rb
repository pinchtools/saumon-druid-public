class SaumonNet::StakeholderMapper
  def initialize(acteur_data)
    @acteur_data = acteur_data
  end

  def map_attributes
    {
      uid: extract_uid,
      civility: identity["civ"],
      gender: determine_gender,
      first_name: identity["prenom"],
      last_name: identity["nom"],
      birth_date: SaumonNet::DateParser.parse_date(birth_info["dateNais"]),
      birth_city: sanitize_value(birth_info["villeNais"]),
      birth_province: sanitize_value(birth_info["depNais"]),
      birth_country: sanitize_value(birth_info["paysNais"]),
      death_date: SaumonNet::DateParser.parse_date(civil_identity["dateDeces"]),
      occupation: sanitize_value(profession_data["libelleCourant"]),
      occupation_category: sanitize_value(profession_data.dig("socProcINSEE", "catSocPro")),
      occupation_family: sanitize_value(profession_data.dig("socProcINSEE", "famSocPro")),
      emails: [],
      urls: [],
      phone_numbers: []
    }
  end

  private

  def civil_identity
    @civil_identity ||= @acteur_data["etatCivil"] || {}
  end

  def identity
    @identity ||= civil_identity["ident"] || {}
  end

  def birth_info
    @birth_info ||= civil_identity["infoNaissance"] || {}
  end

  def profession_data
    @profession_data ||= @acteur_data["profession"] || {}
  end

  def extract_uid
    uid_data = @acteur_data["uid"]

    case uid_data
    when Hash
      uid_data["#text"]
    when String
      uid_data
    else
      nil
    end
  end

  def determine_gender
    identity["civ"] == "M." ? "male" : "female"
  end

  def sanitize_value(value)
    return nil if value.blank? || !value.is_a?(String)

    value
  end
end
