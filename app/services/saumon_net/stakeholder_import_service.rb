module SaumonNet
  class StakeholderImportService < BaseImportService
    attr_reader :term_qualities
    def initialize
      super("acteur")
      @term_qualities = []
    end

    private

    def map_entity_attributes(entity_data)
      file_details = entity_data["file_details"] || entity_data
      acteur_data = file_details["acteur"] || file_details


      civil_identity = acteur_data["etatCivil"] || {}
      identity = civil_identity["ident"] || {}
      birth_info = civil_identity["infoNaissance"] || {}
      death_date = civil_identity["dateDeces"]

      profession_data = acteur_data["profession"] || {}

      file_uid = extract_file_uid(acteur_data)

      {
        uid: file_uid,
        civility: identity["civ"],
        first_name: identity["prenom"].downcase,
        last_name: identity["nom"].downcase,
        birth_date: parse_date(birth_info["dateNais"]),
        birth_city: sanitize_entity_value(birth_info["villeNais"]),
        birth_province: sanitize_entity_value(birth_info["depNais"]),
        birth_country: sanitize_entity_value(birth_info["paysNais"]),
        death_date: parse_date(death_date),
        occupation: sanitize_entity_value(profession_data["libelleCourant"]),
        occupation_category: sanitize_entity_value(profession_data.dig("socProcINSEE", "catSocPro")),
        occupation_family: sanitize_entity_value(profession_data.dig("socProcINSEE", "famSocPro")),
        emails: [],
        urls: [],
        phone_numbers: []
      }
    end

    def find_or_initialize_record(attributes)
      An::Stakeholder.find_or_initialize_by(uid: attributes[:uid]) do |stakeholder|
        stakeholder.assign_attributes(attributes)
      end.tap do |stakeholder|
        stakeholder.assign_attributes(attributes) unless stakeholder.new_record?
      end
    end

    def perform_additional_operations(record, entity_data, operation_type)
      super

      return unless record.persisted?

      upsert_stakeholder_addresses(record, entity_data)
      upsert_terms(record, entity_data)
    end

    def extract_file_uid(acteur_data)
      uid_data = acteur_data["uid"]

      case uid_data
      when Hash
        uid_data["#text"]
      when String
        uid_data
      else
        nil
      end
    end

    def parse_date(date_string)
      return nil if date_string.blank? || !date_string.is_a?(String)

      Date.parse(date_string)
    rescue ArgumentError => e
      logger.warn({
        message: "Failed to parse date",
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        date_string: date_string,
        error: e.message
      })
      nil
    end

    def upsert_stakeholder_addresses(stakeholder, entity_data)
      file_details = entity_data["file_details"] || entity_data
      acteur_data = file_details["acteur"] || file_details
      addresses_data = acteur_data["adresses"] || {}

      address_entries = addresses_data["adresse"]
      return unless address_entries.present?

      address_entries = [ address_entries ] unless address_entries.is_a?(Array)

      emails = []
      urls = []
      phone_numbers = []

      address_entries.each do |address_data|
        next unless address_data.is_a?(Hash)


        case address_data["@xsi:type"]
        when "AdresseMail_Type"
          emails << address_data["valElec"] if address_data["valElec"].present?
        when "AdresseSiteWeb_Type"
          if address_data["valElec"].present?
            url = build_website_url(address_data)
            urls << url if url.present?
          end
        when "AdresseTelephonique_Type"
          phone_numbers << address_data["numeroTelephone"] if address_data["numeroTelephone"].present?
        when "AdressePostale_Type"
          upsert_single_address(stakeholder, address_data)
        end
      end

      # Update stakeholder with collected contact arrays
      update_stakeholder_contact_arrays(stakeholder, emails, urls, phone_numbers)
    rescue => e
      logger.error({
        message: "Failed to upsert stakeholder addresses",
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        stakeholder_uid: stakeholder.uid,
        error: e.message
      })
    end

    def update_stakeholder_contact_arrays(stakeholder, emails, urls, phone_numbers)
      stakeholder.emails = (stakeholder.emails + emails).uniq.compact
      stakeholder.urls = (stakeholder.urls + urls).uniq.compact
      stakeholder.phone_numbers = (stakeholder.phone_numbers + phone_numbers).uniq.compact

      stakeholder.save! if stakeholder.changed?
    end

    def upsert_single_address(stakeholder, address_data)
      address_uid = address_data["uid"]
      return unless address_uid.present?

      address_attributes = map_address_attributes(address_data, stakeholder)

      address = An::StakeholderAddress.find_or_initialize_by(
        uid: address_uid,
        an_stakeholder: stakeholder
      )

      address.assign_attributes(address_attributes)

      if address.new_record? || address.changed?
        address.save!
        operation = address.previously_new_record? ? "created" : "updated"

        logger.debug({
          message: "Address #{operation}",
          component: SaumonNet::COMPONENT,
          session_id: session_id,
          stakeholder_uid: stakeholder.uid,
          address_uid: address_uid
        })
      end
    end

    def map_address_attributes(address_data, stakeholder)
      {
        uid: address_data["uid"],
        an_stakeholder: stakeholder,
        address_1: address_data["intitule"],
        address_2: address_data["complementAdresse"],
        street_number: address_data["numeroRue"],
        street_name: address_data["nomRue"],
        post_code: address_data["codePostal"],
        city: address_data["ville"],
        weight: address_data["poids"]&.to_i,
        type: address_data["type"]&.to_i
      }
    end

    def upsert_terms(stakeholder, entity_data)
      file_details = entity_data["file_details"] || entity_data
      acteur_data = file_details["acteur"] || file_details
      mandates_data = acteur_data["mandats"] || {}

      mandate_entries = mandates_data["mandat"]
      return unless mandate_entries.present?

      # Handle both single mandate and array of mandates
      mandate_entries = [ mandate_entries ] unless mandate_entries.is_a?(Array)

      mandate_entries.each do |mandate_data|
        next unless mandate_data.is_a?(Hash)

        upsert_single_term(stakeholder, mandate_data)
      end
    rescue => e
      logger.error({
        message: "Failed to upsert stakeholder terms",
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        stakeholder_uid: stakeholder.uid,
        error: e.message
      })
    end

    def upsert_single_term(stakeholder, mandate_data)
      term_uid = mandate_data["uid"]
      return unless term_uid.present?

      term_attributes = map_term_attributes(mandate_data, stakeholder)

      term = An::Term.find_or_initialize_by(uid: term_uid)
      term.assign_attributes(term_attributes)

      if term.new_record? || term.changed?
        term.save!
        operation = term.previously_new_record? ? "created" : "updated"

        logger.debug({
          message: "Term #{operation}",
          component: SaumonNet::COMPONENT,
          session_id: session_id,
          stakeholder_uid: stakeholder.uid,
          term_uid: term_uid
        })
      end

      upsert_substitutes(term, mandate_data)
    rescue => e
      logger.error({
        message: "Failed to upsert single term",
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        stakeholder_uid: stakeholder.uid,
        term_uid: term_uid,
        error: e.message
      })
    end

    def map_term_attributes(mandate_data, stakeholder)
      body = find_body_by_uid(mandate_data.dig("organes", "organeRef"))


      constituency = nil
      deputy_term = nil

      if mandate_data["@xsi:type"] == "MandatParlementaire_type"
        constituency_ref = mandate_data.dig("election", "refCirconscription")
        constituency = find_body_by_uid(constituency_ref) if constituency_ref.present?
        mandat_remplace_ref = mandate_data.dig("mandature", "mandatRemplaceRef")
        deputy_term = find_deputy_term_by_uid(mandat_remplace_ref) if mandat_remplace_ref.present?
      end

      {
        uid: mandate_data["uid"],
        an_stakeholder: stakeholder,
        an_body: body,
        constituency: constituency,
        deputy_term: deputy_term,
        legislature: mandate_data["legislature"],
        start_date: parse_datetime(mandate_data["dateDebut"]),
        end_date: parse_datetime(mandate_data["dateFin"]),
        publish_date: parse_datetime(mandate_data["datePublication"]),
        assumption_date: parse_assumption_date(mandate_data),
        role_rank: mandate_data["preseance"]&.to_i,
        main: mandate_data["nominPrincipale"] == "1",
        origin: extract_origin(mandate_data),
        end_reason: extract_end_reason(mandate_data),
        seat: extract_seat_info(mandate_data),
        collaborators: extract_collaborators(mandate_data)
      }
    end

    def find_body_by_uid(body_uid)
      return nil if body_uid.blank?

      An::Body.find_by(uid: body_uid).tap do |body|
        if body.nil?
          logger.warn({
            message: "Body not found for UID",
            component: SaumonNet::COMPONENT,
            session_id: session_id,
            body_uid: body_uid
          })
        end
      end
    end

    def find_deputy_term_by_uid(term_uid)
      return nil if term_uid.blank?

      An::Term.find_by(uid: term_uid).tap do |term|
        if term.nil?
          logger.warn({
            message: "Deputy term not found for UID",
            component: SaumonNet::COMPONENT,
            session_id: session_id,
            term_uid: term_uid
          })
        end
      end
    end

    def parse_datetime(date_string)
      return nil if date_string.blank? || !date_string.is_a?(String)

      DateTime.parse(date_string)
    rescue ArgumentError => e
      logger.warn({
        message: "Failed to parse datetime",
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        date_string: date_string,
        error: e.message
      })
      nil
    end

    def parse_assumption_date(mandate_data)
      if mandate_data["@xsi:type"] == "MandatParlementaire_type"
        return parse_datetime(mandate_data.dig("mandature", "datePriseFonction"))
      end

      nil
    end

    def extract_origin(mandate_data)
      if mandate_data["@xsi:type"] == "MandatParlementaire_type"
        return mandate_data.dig("election", "causeMandat")
      end

      nil
    end

    def extract_end_reason(mandate_data)
      if mandate_data["@xsi:type"] == "MandatParlementaire_type"
        return mandate_data.dig("mandature", "causeFin")
      end

      nil
    end

    def extract_seat_info(mandate_data)
      mandate_data.dig("mandature", "placeHemicycle")
    end

    def extract_collaborators(mandate_data)
      collaborateurs_data = mandate_data["collaborateurs"]
      return [] unless collaborateurs_data.present?

      collaborateur_entries = collaborateurs_data["collaborateur"]
      return [] unless collaborateur_entries.present?

      # Handle both single collaborator and array of collaborators
      collaborateur_entries = [ collaborateur_entries ] unless collaborateur_entries.is_a?(Array)

      collaborateur_entries.map do |collaborateur|
        next unless collaborateur.is_a?(Hash)

        # Build name from qualite, prenom, nom
        parts = [
          collaborateur["qualite"],
          collaborateur["prenom"],
          collaborateur["nom"]
        ].compact.reject(&:blank?)

        parts.join(" ").strip.presence
      end.compact
    end

    def build_website_url(address_data)
      val_elec = address_data["valElec"]
      type_libelle = address_data["typeLibelle"]

      # Handle Facebook edge case
      if type_libelle&.downcase == "facebook"
        "https://facebook.com/#{val_elec}"
      elsif type_libelle&.downcase == "twitter"
        "https://twitter.com/#{val_elec}"
      elsif type_libelle&.downcase == "instagram"
        "https://instagram.com/#{val_elec}"
      elsif type_libelle&.downcase == "linkedin"
        "https://linkedin.com/#{val_elec}"
      else
        val_elec
      end
    end

    def upsert_substitutes(term, mandate_data)
      suppleants_data = mandate_data["suppleants"]
      return unless suppleants_data.present?

      suppleant_entries = suppleants_data["suppleant"]
      return unless suppleant_entries.present?

      suppleant_entries = [ suppleant_entries ] unless suppleant_entries.is_a?(Array)

      suppleant_entries.each do |suppleant_data|
        next unless suppleant_data.is_a?(Hash)

        upsert_single_substitute(term, suppleant_data)
      end
    rescue => e
      logger.error({
        message: "Failed to upsert substitutes",
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        term_uid: term.uid,
        error: e.message
      })
    end

    def upsert_single_substitute(term, suppleant_data)
      stakeholder_uid = suppleant_data["suppleantRef"]
      return unless stakeholder_uid.present?

      # Find the stakeholder by uid
      stakeholder = An::Stakeholder.find_by(uid: stakeholder_uid)
      unless stakeholder
        logger.warn({
          message: "Stakeholder not found for substitute",
          component: SaumonNet::COMPONENT,
          session_id: session_id,
          stakeholder_uid: stakeholder_uid,
          term_uid: term.uid
        })
        return
      end

      start_date = parse_datetime(suppleant_data["dateDebut"])
      end_date = parse_datetime(suppleant_data["dateFin"])

      substitute_attributes = {
        an_term: term,
        an_stakeholder: stakeholder,
        start_date: start_date,
        end_date: end_date
      }

      substitute = An::Substitute.find_or_initialize_by(
        an_term: term,
        an_stakeholder: stakeholder,
        start_date: start_date
      )

      substitute.assign_attributes(substitute_attributes)

      if substitute.new_record? || substitute.changed?
        substitute.save!
        operation = substitute.previously_new_record? ? "created" : "updated"

        logger.debug({
          message: "Substitute #{operation}",
          component: SaumonNet::COMPONENT,
          session_id: session_id,
          term_uid: term.uid,
          stakeholder_uid: stakeholder_uid
        })
      end
    rescue => e
      logger.error({
        message: "Failed to upsert single substitute",
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        term_uid: term&.uid,
        stakeholder_uid: stakeholder_uid,
        error: e.message
      })
    end
  end
end
