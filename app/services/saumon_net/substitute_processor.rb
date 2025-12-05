module SaumonNet
  class SubstituteProcessor
    include ::Loggable

    def initialize(term, mandate_data, session_id)
      @term = term
      @mandate_data = mandate_data
      @session_id = session_id
    end

    def process
      suppleant_entries = extract_suppleant_entries
      return unless suppleant_entries.present?

      suppleant_entries.each do |suppleant_data|
        next unless suppleant_data.is_a?(Hash)

        upsert_single_substitute(suppleant_data)
      end
    rescue => e
      log_error(e)
    end

    private

    def extract_suppleant_entries
      suppleants_data = @mandate_data["suppleants"]
      return [] unless suppleants_data.present?

      suppleant_entries = suppleants_data["suppleant"]
      return [] unless suppleant_entries.present?

      suppleant_entries.is_a?(Array) ? suppleant_entries : [ suppleant_entries ]
    end

    def upsert_single_substitute(suppleant_data)
      stakeholder_uid = suppleant_data["suppleantRef"]
      return unless stakeholder_uid.present?

      stakeholder = find_stakeholder(stakeholder_uid)
      return unless stakeholder

      substitute_attributes = build_substitute_attributes(suppleant_data, stakeholder)

      substitute = find_or_initialize_substitute(suppleant_data, stakeholder)
      substitute.assign_attributes(substitute_attributes)

      if substitute.new_record? || substitute.changed?
        substitute.save!
        operation = substitute.previously_new_record? ? "created" : "updated"

        log_substitute_operation(operation, stakeholder_uid)
      end
    rescue => e
      log_substitute_error(stakeholder_uid, e)
    end

    def find_stakeholder(stakeholder_uid)
      An::Stakeholder.find_by(uid: stakeholder_uid).tap do |stakeholder|
        unless stakeholder
          logger.warn({
            message: "Stakeholder not found for substitute",
            component: SaumonNet::COMPONENT,
            session_id: @session_id,
            stakeholder_uid: stakeholder_uid,
            term_uid: @term.uid
          })
        end
      end
    end

    def build_substitute_attributes(suppleant_data, stakeholder)
      start_date = DateParser.parse_datetime(suppleant_data["dateDebut"], session_id: @session_id)
      end_date = DateParser.parse_datetime(suppleant_data["dateFin"], session_id: @session_id)

      {
        an_term: @term,
        an_stakeholder: stakeholder,
        start_date: start_date,
        end_date: end_date
      }
    end

    def find_or_initialize_substitute(suppleant_data, stakeholder)
      start_date = DateParser.parse_datetime(suppleant_data["dateDebut"], session_id: @session_id)

      An::Substitute.find_or_initialize_by(
        an_term: @term,
        an_stakeholder: stakeholder,
        start_date: start_date
      )
    end

    def log_substitute_operation(operation, stakeholder_uid)
      logger.debug({
        message: "Substitute #{operation}",
        component: SaumonNet::COMPONENT,
        session_id: @session_id,
        term_uid: @term.uid,
        stakeholder_uid: stakeholder_uid
      })
    end

    def log_error(error)
      logger.error({
        message: "Failed to process substitutes",
        component: SaumonNet::COMPONENT,
        session_id: @session_id,
        term_uid: @term.uid,
        error: error.message
      })
    end

    def log_substitute_error(stakeholder_uid, error)
      logger.error({
        message: "Failed to upsert single substitute",
        component: SaumonNet::COMPONENT,
        session_id: @session_id,
        term_uid: @term&.uid,
        stakeholder_uid: stakeholder_uid,
        error: error.message
      })
    end
  end
end
