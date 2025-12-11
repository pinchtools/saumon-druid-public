class SaumonNet::StakeholderImportService < SaumonNet::BaseImportService
  def initialize
    super("acteur")
  end

  private

  def map_entity_attributes(entity_data)
    acteur_data = extract_acteur_data(entity_data)

    SaumonNet::StakeholderMapper.new(acteur_data).map_attributes
  end

  def find_or_initialize_record(attributes)
    An::Stakeholder.find_or_initialize_by(uid: attributes[:uid]).tap do |stakeholder|
      stakeholder.assign_attributes(attributes)
    end
  end

  def perform_additional_operations(record, entity_data, operation_type)
    super

    return unless record.persisted?

    SaumonNet::AddressProcessor.new(record, entity_data, session_id).process
    SaumonNet::TermProcessor.new(record, entity_data, session_id).process

    An::Stakeholder.with_terms_hierarchy.find(record.id).sync_lexical_search_content
  end

  def extract_acteur_data(entity_data)
    file_details = entity_data["file_details"] || entity_data
    file_details["acteur"] || file_details
  end
end
