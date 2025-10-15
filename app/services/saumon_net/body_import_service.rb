module SaumonNet
  class BodyImportService < BaseImportService
    def initialize
      super("organe")
    end

    private

    def map_entity_attributes(entity_data)
      file_details = entity_data["file_details"] || entity_data

      body_type = find_or_create_body_type(file_details)
      parent_body = find_parent_body(file_details)
      vi_mo_de = file_details["viMoDe"] || {}

      file_uid = extract_file_uid(file_details)

      {
        uid: file_uid,
        an_body_type: body_type,
        parent: parent_body,
        label: file_details["libelle"],
        label_abbr: file_details["libelleAbrev"],
        label_code: file_details["libelleEdition"],
        start_date: parse_date(vi_mo_de["dateDebut"]),
        end_date: parse_date(vi_mo_de["dateFin"]),
        deliver_date: parse_date(vi_mo_de["dateAgrement"]),
        chamber: file_details["chambre"],
        regime: file_details["regime"],
        legislature: file_details["legislature"],
        number: file_details["numero"],
        province: extract_province(file_details),
        department_code: extract_department_code(file_details)
      }
    end

    def find_or_initialize_record(attributes)
      An::Body.find_or_initialize_by(uid: attributes[:uid]) do |body|
        body.assign_attributes(attributes)
      end.tap do |body|
        body.assign_attributes(attributes) unless body.new_record?
      end
    end

    def find_or_create_body_type(file_details)
      type_code = determine_body_type_code(file_details)

      An::BodyType.find_by(code: type_code) || begin
        logger.warn({ message: "Unknown body type code",
          component: SaumonNet::COMPONENT,
          session_id: session_id,
          code: type_code,
          entity_uid: file_details["uid"]
        })

        An::BodyType.create!(code: type_code)
      end
    end

    def find_parent_body(file_details)
      parent_uid = file_details["organeParent"]
      return nil if parent_uid.blank?

      An::Body.find_by(uid: parent_uid)
    end

    def determine_body_type_code(file_details)
      code_type = file_details["codeType"]
      return "UNKNOWN" if code_type.nil? || code_type.to_s.strip.empty?

      code_type.to_s.strip.upcase
    end

    def parse_date(date_string)
      return nil if date_string.blank? || !date_string.is_a?(String)

      Date.parse(date_string)
    rescue ArgumentError => e
      logger.warn({ message: "Failed to parse date",
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        date_string: date_string,
        error: e.message
      })
      nil
    end

    def location_attributes(file_details)
      file_details["lieu"] || {}
    end

    def extract_province(file_details)
      file_details.dig("lieu", "region", "libelle")
    end

    def extract_department_code(file_details)
      file_details.dig("lieu", "departement", "code")
    end

    def perform_additional_operations(record, entity_data, operation_type)
      super

      create_country_association(record, entity_data)
    end

    def create_country_association(body, entity_data)
      file_details = entity_data["file_details"] || entity_data
      pays_ref = file_details.dig("listePays", "paysRef")

      return unless pays_ref.present?

      country = An::Country.find_by(uid: pays_ref)

      log_hash = {
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        body_uid: body&.uid
      }

      if country
        body.an_countries << country unless body.an_countries.include?(country)

        logger.debug(log_hash.merge({
                                      message: "Associated country with body",
                                      country_uid: country.uid
          }))
      else
        logger.warn(log_hash.merge({
                                     message: "Country not found for pays_ref",
                                     pays_ref: pays_ref
        }))
      end
    rescue => e
      logger.error(log_hash.merge({
                                    message: "Failed to create country association",
                                    error: e.message
      }))
    end

    def extract_file_uid(file_details)
      uid_data = file_details["uid"]

      case uid_data
      when Hash
        uid_data["#text"]
      when String
        uid_data
      else
        nil
      end
    end
  end
end
