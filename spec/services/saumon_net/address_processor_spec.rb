require 'rails_helper'

RSpec.describe SaumonNet::AddressProcessor do
  let(:stakeholder) { create(:an_stakeholder, emails: [], urls: [], phone_numbers: []) }
  let(:session_id) { 'test-session-id' }
  let(:logger) { double('logger', error: nil) }

  subject(:processor) { described_class.new(stakeholder, entity_data, session_id) }

  let(:test_email) { "test@example.com" }
  let(:test_website) { "https://facebook.com/test-profile" }
  let(:test_phone) { "01 23 45 67 89" }
  let(:existing_email) { "existing@example.com" }
  let(:existing_website) { "https://existing.com" }
  let(:existing_phone) { "09 87 65 43 21" }
  let(:address_uid) { "ADR123" }
  let(:address_label) { "Bureau" }
  let(:address_city) { "Paris" }

  let(:entity_data) do
    {
      "file_details" => {
        "acteur" => {
          "adresses" => {
            "adresse" => [
              {
                "@xsi:type" => "AdresseMail_Type",
                "valElec" => test_email
              },
              {
                "@xsi:type" => "AdresseSiteWeb_Type",
                "typeLibelle" => "Facebook",
                "valElec" => "test-profile"
              },
              {
                "@xsi:type" => "AdresseTelephonique_Type",
                "numeroTelephone" => test_phone
              },
              {
                "@xsi:type" => "AdressePostale_Type",
                "uid" => address_uid,
                "intitule" => address_label,
                "ville" => address_city
              }
            ]
          }
        }
      }
    }
  end

  describe '#process' do
    it 'updates stakeholder with contact information' do
      processor.process

      stakeholder.reload
      expect(stakeholder.emails).to include(test_email)
      expect(stakeholder.urls).to include(test_website)
      expect(stakeholder.phone_numbers).to include(test_phone)
    end

    it 'merges new contact info with existing' do
      stakeholder.update!(
        emails: [ existing_email ],
        urls: [ existing_website ],
        phone_numbers: [ existing_phone ]
      )
      processor.process

      stakeholder.reload
      expect(stakeholder.emails).to include(existing_email, test_email)
      expect(stakeholder.urls).to include(existing_website, test_website)
      expect(stakeholder.phone_numbers).to include(existing_phone, test_phone)
    end

    it 'removes duplicate contact info' do
      stakeholder.update!(
        emails: [ test_email ],
        urls: [ test_website ]
      )

      processor.process

      stakeholder.reload
      expect(stakeholder.emails.count(test_email)).to eq(1)
      expect(stakeholder.urls.count(test_website)).to eq(1)
    end

    it 'creates postal address records' do
      expect {
        processor.process
      }.to change(An::StakeholderAddress, :count).by(1)

      address = An::StakeholderAddress.last
      expect(address.uid).to eq(address_uid)
      expect(address.address_1).to eq(address_label)
      expect(address.city).to eq(address_city)
    end

    context 'when no addresses present' do
      let(:entity_data) { { "file_details" => { "acteur" => {} } } }

      it 'returns early' do
        expect {
          processor.process
        }.not_to change(An::StakeholderAddress, :count)
      end
    end

    it 'logs error when processing fails' do
      allow_any_instance_of(SaumonNet::ContactInfoExtractor).to receive(:extract_emails).and_raise(StandardError.new("Test error"))
      allow(processor).to receive(:logger).and_return(logger)

      expect { processor.process }.to raise_error(StandardError)

      expect(logger).to have_received(:error).with(hash_including(
        message: "Failed to process stakeholder addresses",
        error: "Test error"
      ))
    end
  end
end
