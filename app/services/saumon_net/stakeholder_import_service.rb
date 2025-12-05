module SaumonNet
  class StakeholderImportService < BaseImportService
    def initialize
      super("acteur")
    end

    private

    def map_entity_attributes(entity_data)
      acteur_data = extract_acteur_data(entity_data)

      StakeholderMapper.new(acteur_data).map_attributes
    end

    def find_or_initialize_record(attributes)
      An::Stakeholder.find_or_initialize_by(uid: attributes[:uid]).tap do |stakeholder|
        stakeholder.assign_attributes(attributes)
      end
    end

    def perform_additional_operations(record, entity_data, operation_type)
      super
      return unless record.persisted?

      AddressProcessor.new(record, entity_data, session_id).process
      TermProcessor.new(record, entity_data, session_id).process

      record.sync_search_fields if record.respond_to?(:sync_search_fields)
    end

    def extract_acteur_data(entity_data)
      file_details = entity_data["file_details"] || entity_data
      file_details["acteur"] || file_details
    end
  end
end
