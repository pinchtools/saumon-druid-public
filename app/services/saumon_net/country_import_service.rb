module SaumonNet
  class CountryImportService < BaseImportService
    def initialize
      super("pays")
    end

    private

    def map_entity_attributes(entity_data)
      # Use file_details if available, otherwise fall back to entity_data
      file_details = entity_data["file_details"] || entity_data

      {
        uid: entity_data["uid"],
        name: file_details["nomCourant"] || file_details["libelleANLong"],
        insee_code: file_details["code_insee"],
        insee_name: file_details["libelleInsee"],
        iso_code: file_details["code_iso3A"],
        active: parse_boolean(file_details["activ"])
      }
    end

    def find_or_initialize_record(attributes)
      An::Country.find_or_initialize_by(uid: attributes[:uid]) do |country|
        country.assign_attributes(attributes)
      end.tap do |country|
        country.assign_attributes(attributes) unless country.new_record?
      end
    end

    def parse_boolean(value)
      return true if value.blank?

      case value.to_s.downcase
      when "true", "1", "yes"
        true
      when "false", "0", "no"
        false
      else
        true
      end
    end
  end
end
