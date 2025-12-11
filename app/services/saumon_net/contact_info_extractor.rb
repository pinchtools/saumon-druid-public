class SaumonNet::ContactInfoExtractor
  def initialize(addresses_data)
    @addresses_data = addresses_data
  end

  def extract_emails
    address_entries.select { |addr| addr["@xsi:type"] == "AdresseMail_Type" }
                   .map { |addr| addr["valElec"] }
                   .compact
  end

  def extract_urls
    address_entries.select { |addr| addr["@xsi:type"] == "AdresseSiteWeb_Type" }
                   .filter_map { |addr| build_url(addr) }
  end

  def extract_phone_numbers
    address_entries.select { |addr| addr["@xsi:type"] == "AdresseTelephonique_Type" }
                   .map { |addr| addr["numeroTelephone"] }
                   .compact
  end

  def postal_addresses
    address_entries.select { |addr| addr["@xsi:type"] == "AdressePostale_Type" }
  end

  private

  def address_entries
    @address_entries ||= Array.wrap(@addresses_data["adresse"]).select { |entry| entry.is_a?(Hash) }
  end

  def build_url(address_data)
    return nil unless address_data["valElec"].present?

    SaumonNet::WebsiteUrlBuilder.build(address_data)
  end
end
