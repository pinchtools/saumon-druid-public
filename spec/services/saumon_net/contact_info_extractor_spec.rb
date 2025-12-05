require 'rails_helper'

RSpec.describe SaumonNet::ContactInfoExtractor do
  let(:test_email) { "jean.doe@example.com" }
  let(:test_website_profile) { "jean-doe-profile" }
  let(:test_website_url) { "https://facebook.com/jean-doe-profile" }
  let(:test_phone) { "01 23 45 67 89" }
  let(:address_uid) { "ADR123" }
  let(:address_label) { "Bureau" }
  let(:single_email) { "single@example.com" }
  let(:edge_case_email) { "test@example.com" }
  let(:social_platform) { "Facebook" }

  let(:type_email) { "AdresseMail_Type" }
  let(:type_website) { "AdresseSiteWeb_Type" }
  let(:type_phone) { "AdresseTelephonique_Type" }
  let(:type_postal) { "AdressePostale_Type" }

  let(:addresses_data) do
    {
      "adresse" => [
        {
          "@xsi:type" => type_email,
          "valElec" => test_email
        },
        {
          "@xsi:type" => type_website,
          "typeLibelle" => social_platform,
          "valElec" => test_website_profile
        },
        {
          "@xsi:type" => type_phone,
          "numeroTelephone" => test_phone
        },
        {
          "@xsi:type" => type_postal,
          "uid" => address_uid,
          "intitule" => address_label
        }
      ]
    }
  end

  describe '#extract_emails' do
    it 'extracts email addresses from address entries' do
      extractor = described_class.new(addresses_data)
      emails = extractor.extract_emails

      expect(emails).to eq([ test_email ])
    end

    it 'returns empty array when no emails present' do
      data = { "adresse" => [ { "@xsi:type" => type_postal } ] }
      extractor = described_class.new(data)

      expect(extractor.extract_emails).to eq([])
    end

    it 'handles single address entry (not array)' do
      data = {
        "adresse" => {
          "@xsi:type" => type_email,
          "valElec" => single_email
        }
      }
      extractor = described_class.new(data)

      expect(extractor.extract_emails).to eq([ single_email ])
    end
  end

  describe '#extract_urls' do
    it 'extracts and builds URLs from address entries' do
      extractor = described_class.new(addresses_data)
      urls = extractor.extract_urls

      expect(urls).to eq([ test_website_url ])
    end

    it 'returns empty array when no URLs present' do
      data = { "adresse" => [ { "@xsi:type" => type_email } ] }
      extractor = described_class.new(data)

      expect(extractor.extract_urls).to eq([])
    end

    it 'filters out entries with blank valElec' do
      data = {
        "adresse" => [
          {
            "@xsi:type" => type_website,
            "typeLibelle" => social_platform,
            "valElec" => ""
          }
        ]
      }
      extractor = described_class.new(data)

      expect(extractor.extract_urls).to eq([])
    end
  end

  describe '#extract_phone_numbers' do
    it 'extracts phone numbers from address entries' do
      extractor = described_class.new(addresses_data)
      phone_numbers = extractor.extract_phone_numbers

      expect(phone_numbers).to eq([ test_phone ])
    end

    it 'returns empty array when no phone numbers present' do
      data = { "adresse" => [ { "@xsi:type" => type_email } ] }
      extractor = described_class.new(data)

      expect(extractor.extract_phone_numbers).to eq([])
    end
  end

  describe '#postal_addresses' do
    it 'returns only postal address entries' do
      extractor = described_class.new(addresses_data)
      postal = extractor.postal_addresses

      expect(postal.length).to eq(1)
      expect(postal.first["@xsi:type"]).to eq(type_postal)
      expect(postal.first["uid"]).to eq(address_uid)
    end

    it 'returns empty array when no postal addresses present' do
      data = { "adresse" => [ { "@xsi:type" => type_email } ] }
      extractor = described_class.new(data)

      expect(extractor.postal_addresses).to eq([])
    end
  end

  describe 'edge cases' do
    it 'handles missing adresse key' do
      extractor = described_class.new({})

      expect(extractor.extract_emails).to eq([])
      expect(extractor.extract_urls).to eq([])
      expect(extractor.extract_phone_numbers).to eq([])
      expect(extractor.postal_addresses).to eq([])
    end

    it 'filters out non-hash entries' do
      data = {
        "adresse" => [
          { "@xsi:type" => type_email, "valElec" => edge_case_email },
          "invalid",
          nil
        ]
      }
      extractor = described_class.new(data)

      expect(extractor.extract_emails).to eq([ edge_case_email ])
    end
  end
end
