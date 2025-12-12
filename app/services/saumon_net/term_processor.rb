class SaumonNet::TermProcessor
  include ::Loggable

  def initialize(stakeholder, entity_data, session_id)
    @stakeholder = stakeholder
    @entity_data = entity_data
    @session_id = session_id
  end

  def process
    mandate_entries = extract_mandate_entries
    return unless mandate_entries.present?

    mandate_entries.each do |mandate_data|
      next unless mandate_data.is_a?(Hash)

      SaumonNet::TermUpserter.new(@stakeholder, mandate_data, @session_id).upsert
    end
  rescue => e
    log_error(e)
    raise
  end

  private

  def extract_mandate_entries
    acteur_data = @entity_data["file_details"] || @entity_data
    acteur_data = acteur_data["acteur"] || acteur_data
    mandates_data = acteur_data["mandats"] || {}

    mandate_entries = mandates_data["mandat"]
    return [] unless mandate_entries.present?

    mandate_entries.is_a?(Array) ? mandate_entries : [ mandate_entries ]
  end

  def log_error(error)
    logger.error({
      message: "Failed to process stakeholder terms",
      component: SaumonNet::COMPONENT,
      session_id: @session_id,
      stakeholder_uid: @stakeholder.uid,
      error: error.message
    })
  end
end
