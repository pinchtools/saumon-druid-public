require 'rails_helper'

RSpec.describe SaumonNet::WebsiteUrlBuilder do
  describe '.build' do
    it 'handles Facebook type by prepending Facebook URL' do
      address_data = {
        "typeLibelle" => "Facebook",
        "valElec" => "jean-francois-cesarini-profile"
      }

      result = described_class.build(address_data)
      expect(result).to eq("https://facebook.com/jean-francois-cesarini-profile")
    end

    it 'handles Facebook type case insensitively' do
      address_data = {
        "typeLibelle" => "FACEBOOK",
        "valElec" => "test-profile"
      }

      result = described_class.build(address_data)
      expect(result).to eq("https://facebook.com/test-profile")
    end

    it 'handles Twitter type' do
      address_data = {
        "typeLibelle" => "Twitter",
        "valElec" => "@test"
      }

      result = described_class.build(address_data)
      expect(result).to eq("https://twitter.com/@test")
    end

    it 'handles Instagram type' do
      address_data = {
        "typeLibelle" => "Instagram",
        "valElec" => "test_profile"
      }

      result = described_class.build(address_data)
      expect(result).to eq("https://instagram.com/test_profile")
    end

    it 'handles LinkedIn type' do
      address_data = {
        "typeLibelle" => "LinkedIn",
        "valElec" => "test-profile"
      }

      result = described_class.build(address_data)
      expect(result).to eq("https://linkedin.com/test-profile")
    end

    it 'returns original valElec for non-social platform types' do
      address_data = {
        "typeLibelle" => "Website",
        "valElec" => "https://example.com"
      }

      result = described_class.build(address_data)
      expect(result).to eq("https://example.com")
    end

    it 'returns original valElec when typeLibelle is missing' do
      address_data = {
        "valElec" => "test-profile"
      }

      result = described_class.build(address_data)
      expect(result).to eq("test-profile")
    end
  end
end
