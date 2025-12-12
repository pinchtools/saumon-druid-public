class SaumonNet::AddressProcessor
  include ::Loggable

  def initialize(stakeholder, entity_data, session_id)
    @stakeholder = stakeholder
    @entity_data = entity_data
    @session_id = session_id
  end

  def process
    addresses_data = extract_addresses_data
    return unless addresses_data.present?

    contact_extractor = SaumonNet::ContactInfoExtractor.new(addresses_data)

    upsert_postal_addresses(contact_extractor.postal_addresses)
    update_contact_info(contact_extractor)
  rescue => e
    log_error(e)
    raise
  end

  private

  def extract_addresses_data
    acteur_data = @entity_data["file_details"] || @entity_data
    acteur_data = acteur_data["acteur"] || acteur_data
    acteur_data["adresses"] || {}
  end

  def upsert_postal_addresses(postal_addresses)
    postal_addresses.each do |address_data|
      SaumonNet::PostalAddressUpserter.new(@stakeholder, address_data, @session_id).upsert
    end
  end

  def update_contact_info(contact_extractor)
    @stakeholder.emails = (@stakeholder.emails + contact_extractor.extract_emails).uniq.compact
    @stakeholder.urls = (@stakeholder.urls + contact_extractor.extract_urls).uniq.compact
    @stakeholder.phone_numbers = (@stakeholder.phone_numbers + contact_extractor.extract_phone_numbers).uniq.compact

    @stakeholder.save! if @stakeholder.changed?
  end

  def log_error(error)
    logger.error({
      message: "Failed to process stakeholder addresses",
      component: SaumonNet::COMPONENT,
      session_id: @session_id,
      stakeholder_uid: @stakeholder.uid,
      error: error.message
    })
  end
end
