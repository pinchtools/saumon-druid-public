class SaumonNet::PostalAddressUpserter
  include ::Loggable

  def initialize(stakeholder, address_data, session_id)
    @stakeholder = stakeholder
    @address_data = address_data
    @session_id = session_id
  end

  def upsert
    address_uid = @address_data["uid"]
    return unless address_uid.present?

    address_attributes = map_address_attributes

    address = An::StakeholderAddress.find_or_initialize_by(
      uid: address_uid,
      an_stakeholder: @stakeholder
    )

    address.assign_attributes(address_attributes)

    if address.new_record? || address.changed?
      address.save!
      operation = address.previously_new_record? ? "created" : "updated"

      log_address_operation(operation, address_uid)
    end
  end

  private

  def map_address_attributes
    type = determine_address_type

    {
      uid: @address_data["uid"],
      an_stakeholder: @stakeholder,
      address_1: @address_data["intitule"],
      address_2: @address_data["complementAdresse"],
      street_number: @address_data["numeroRue"],
      street_name: @address_data["nomRue"],
      post_code: @address_data["codePostal"],
      city: @address_data["ville"],
      weight: @address_data["poids"]&.to_i,
      address_type: type
    }
  end

  def determine_address_type
    return "other" unless @address_data["type"].present?

    type_index = @address_data["type"].to_i
    An::StakeholderAddress::ADDRESS_TYPES.at(type_index) || "other"
  end

  def log_address_operation(operation, address_uid)
    logger.debug({
      message: "Address #{operation}",
      component: SaumonNet::COMPONENT,
      session_id: @session_id,
      stakeholder_uid: @stakeholder.uid,
      address_uid: address_uid
    })
  end
end
