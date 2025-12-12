class SaumonNet::TermUpserter
  include ::Loggable

  def initialize(stakeholder, mandate_data, session_id)
    @stakeholder = stakeholder
    @mandate_data = mandate_data
    @session_id = session_id
  end

  def upsert
    term_uid = @mandate_data["uid"]
    return unless term_uid.present?

    term_attributes = map_term_attributes

    term = An::Term.find_or_initialize_by(uid: term_uid)
    term.assign_attributes(term_attributes)

    if term.new_record? || term.changed?
      term.save!
      operation = term.previously_new_record? ? "created" : "updated"

      log_term_operation(operation, term_uid)
    end

    SaumonNet::SubstituteProcessor.new(term, @mandate_data, @session_id).process
    apply_corrections(term)
  rescue => e
    log_error(term_uid, e)
    raise
  end

  private

  def map_term_attributes
    body = find_body_by_uid(@mandate_data.dig("organes", "organeRef"))
    constituency = extract_constituency
    deputy_term = extract_deputy_term
    capacity = extract_capacity

    {
      uid: @mandate_data["uid"],
      label: build_label(capacity, body, constituency),
      an_stakeholder: @stakeholder,
      an_body: body,
      constituency: constituency,
      deputy_term: deputy_term,
      legislature: @mandate_data["legislature"],
      start_date: SaumonNet::DateParser.parse_datetime(@mandate_data["dateDebut"], session_id: @session_id),
      end_date: SaumonNet::DateParser.parse_datetime(@mandate_data["dateFin"], session_id: @session_id),
      publish_date: SaumonNet::DateParser.parse_datetime(@mandate_data["datePublication"], session_id: @session_id),
      assumption_date: SaumonNet::DateParser.parse_datetime(SaumonNet::TermAttributeExtractor.extract_assumption_date(@mandate_data), session_id: @session_id),
      role_rank: @mandate_data["preseance"]&.to_i,
      capacity: capacity,
      main: @mandate_data["nominPrincipale"] == "1",
      origin: SaumonNet::TermAttributeExtractor.extract_origin(@mandate_data),
      end_reason: SaumonNet::TermAttributeExtractor.extract_end_reason(@mandate_data),
      seat: SaumonNet::TermAttributeExtractor.extract_seat_info(@mandate_data),
      collaborators: SaumonNet::TermAttributeExtractor.extract_collaborators(@mandate_data)
    }
  end

  def extract_constituency
    return nil unless @mandate_data["@xsi:type"] == "MandatParlementaire_type"

    constituency_ref = @mandate_data.dig("election", "refCirconscription")
    return nil unless constituency_ref.present?

    find_body_by_uid(constituency_ref)
  end

  def extract_deputy_term
    return nil unless @mandate_data["@xsi:type"] == "MandatParlementaire_type"

    mandat_remplace_ref = @mandate_data.dig("mandature", "mandatRemplaceRef")
    return nil unless mandat_remplace_ref.present?

    find_deputy_term_by_uid(mandat_remplace_ref)
  end

  def extract_capacity
    capacity = @mandate_data.dig("infosQualite", "codeQualite")
    return nil unless capacity.present?

    capacity.parameterize(separator: "_").underscore
  end

  def build_label(capacity, body, constituency)
    parts = [
      An::Term.humanize("capacities.#{capacity}.label", default: nil, gender: @stakeholder.gender),
      body&.label_code || body&.label,
      constituency&.label
    ].compact

    parts.join(" ").presence
  end

  def find_body_by_uid(body_uid)
    return nil if body_uid.blank?

    An::Body.find_by(uid: body_uid).tap do |body|
      if body.nil?
        logger.warn({
          message: "Body not found for UID",
          component: SaumonNet::COMPONENT,
          session_id: @session_id,
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
          session_id: @session_id,
          term_uid: term_uid
        })
      end
    end
  end

  def apply_corrections(term)
    return unless term.previously_new_record?

    An::CorrectionApplier.new(term, session_id: @session_id).detect_all.apply
  end

  def log_term_operation(operation, term_uid)
    logger.debug({
      message: "Term #{operation}",
      component: SaumonNet::COMPONENT,
      session_id: @session_id,
      stakeholder_uid: @stakeholder.uid,
      term_uid: term_uid
    })
  end

  def log_error(term_uid, error)
    logger.error({
      message: "Failed to upsert single term",
      component: SaumonNet::COMPONENT,
      session_id: @session_id,
      stakeholder_uid: @stakeholder.uid,
      term_uid: term_uid,
      error: error.message
    })
  end
end
