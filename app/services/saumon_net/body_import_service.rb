module SaumonNet
  class BodyImportService < BaseImportService
    # example of entity data returned by SaumonNet:
    # {"uid" => "ANOD-PO52814",
    #          "type" => "organe",
    #          "file_url" =>
    #            "http://localhost:3004/rails/active_storage/blobs/redirect/eyJfcmFpbHMiOnsiZGF0YSI6MjQ0NzIsInB1ciI6ImJsb2JfaWQifX0=--a1676ecacfd3d1eeada3abe9627451d0f9747066/PO52814
    # .json",
    #          "file_type" => "ExtractedFile",
    #          "metadata" =>
    #            {"uid" => "PO52814",
    #             "numero" => "4",
    #             "regime" => "5ème République",
    #             "chambre" => nil,
    #             "libelle" => "4ème circonscription du Var",
    #             "code_type" => "CIRCONSCRIPTION",
    #             "legislature" => "10",
    #             "libelle_abrev" => "CIRCO",
    #             "organe_parent" => nil,
    #             "libelle_abrege" => "83 Var (° 4°)",
    #             "libelle_edition" => "de la circonscription"},
    #          "updated_at" => "2025-10-05T12:51:50Z"}

    # example of a file content:
    # {"organe":
    #    {"@xmlns": "http://schemas.assemblee-nationale.fr/referentiel",
    #     "@xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
    #     "@xsi:type": "OrganeParlementaireInternational",
    #     "uid": "PO733422",
    #     "codeType": "GA",
    #     "libelle": "France-Serbie",
    #     "libelleEdition": "de France-Serbie",
    #     "libelleAbrege": "Serbie",
    #     "libelleAbrev": "SER",
    #     "viMoDe": {"dateDebut": null, "dateAgrement": "2017-07-19", "dateFin": "2022-06-21"},
    #     "organeParent": null,
    #     "chambre": null,
    #     "regime": "5\u00e8me R\u00e9publique",
    #     "legislature": "15",
    #     "secretariat": {"secretaire01": null, "secretaire02": null},
    #     "lieu": {
    #       "region": {"type": "M\u00e9tropolitain", "libelle": "Nouvelle-Aquitaine"},
    #       "departement": {"codeNatureDep": "M", "code": "19", "libelle": "Corr\u00e8ze"}
    #     }
    #     "listePays": {"paysRef": "GOP756412"}}
    # }

    def initialize
      super("organe")
    end

    private

    def map_entity_attributes(entity_data)
      # Use file_details if available, otherwise fall back to entity_data
      file_details = entity_data["file_details"] || entity_data

      body_type = find_or_create_body_type(file_details)
      parent_body = find_parent_body(file_details)
      vi_mo_de = file_details["viMoDe"] || {}

      {
        uid: entity_data["uid"],
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
      return nil if date_string.blank?

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

      # Find country by UID and associate it with the body
      country = An::Country.find_by(uid: pays_ref)

      if country
        body.an_countries << country unless body.an_countries.include?(country)

        logger.debug({ message: "Associated country with body",
          component: SaumonNet::COMPONENT,
          session_id: session_id,
          body_uid: body.uid,
          country_uid: country.uid
        })
      else
        logger.warn({ message: "Country not found for pays_ref",
          component: SaumonNet::COMPONENT,
          session_id: session_id,
          body_uid: body.uid,
          pays_ref: pays_ref
        })
      end
    rescue => e
      logger.error({ message: "Failed to create country association",
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        body_uid: body&.uid,
        error: e.message
      })
    end
  end
end
