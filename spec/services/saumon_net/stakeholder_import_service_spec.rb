require 'rails_helper'

RSpec.describe SaumonNet::StakeholderImportService do
  let(:service) { described_class.new }

  before do
    allow(SaumonNet).to receive(:configure)
    allow(SaumonNet::HealthMonitoringService).to receive(:record_successful_import)
  end

  describe '#initialize' do
    it 'sets entity_type to "acteur"' do
      expect(service.entity_type).to eq("acteur")
    end
  end

  describe '#map_entity_attributes' do
    let(:uid) { "PA721860" }
    let(:civility) { "M." }
    let(:first_name) { "Jean-François" }
    let(:last_name) { "Cesarini" }
    let(:birth_date_str) { "1970-09-30" }
    let(:birth_city) { "Avignon" }
    let(:birth_province) { "Vaucluse" }
    let(:birth_country) { "France" }
    let(:death_date_str) { "2020-03-29" }
    let(:occupation) { "Industriel-Chef d'entreprise" }
    let(:occupation_category) { "Chefs d'entreprise de 10 salariés ou plus" }
    let(:occupation_family) { "Artisans, commerçants et chefs d'entreprise" }

    let(:entity_data) do
      {
        "uid" => uid,
        "file_details" => {
          "acteur" => {
            "uid" => { "#text" => uid },
            "etatCivil" => {
              "ident" => {
                "civ" => civility,
                "prenom" => first_name,
                "nom" => last_name
              },
              "infoNaissance" => {
                "dateNais" => birth_date_str,
                "villeNais" => birth_city,
                "depNais" => birth_province,
                "paysNais" => birth_country
              },
              "dateDeces" => death_date_str
            },
            "profession" => {
              "libelleCourant" => occupation,
              "socProcINSEE" => {
                "catSocPro" => occupation_category,
                "famSocPro" => occupation_family
              }
            }
          }
        }
      }
    end

    it 'maps entity attributes correctly using StakeholderMapper' do
      result = service.send(:map_entity_attributes, entity_data)

      expect(result).to include(
        uid: uid,
        civility: civility,
        gender: "male",
        first_name: first_name,
        last_name: last_name,
        birth_date: Date.parse(birth_date_str),
        birth_city: birth_city,
        birth_province: birth_province,
        birth_country: birth_country,
        death_date: Date.parse(death_date_str),
        occupation: occupation,
        occupation_category: occupation_category,
        occupation_family: occupation_family,
        emails: [],
        urls: [],
        phone_numbers: []
      )
    end
  end

  describe '#find_or_initialize_record' do
    let(:test_uid) { "PA123456" }
    let(:test_first_name) { "John" }
    let(:test_last_name) { "Doe" }
    let(:attributes) { { uid: test_uid, first_name: test_first_name, last_name: test_last_name } }

    context 'when stakeholder does not exist' do
      it 'creates a new stakeholder' do
        record = service.send(:find_or_initialize_record, attributes)

        expect(record).to be_a(An::Stakeholder)
        expect(record.new_record?).to be true
        expect(record.uid).to eq(test_uid)
      end
    end

    context 'when stakeholder exists' do
      let!(:existing_stakeholder) { create(:an_stakeholder, uid: test_uid, first_name: "Jane") }

      it 'finds and updates the existing stakeholder' do
        record = service.send(:find_or_initialize_record, attributes)

        expect(record.persisted?).to be true
        expect(record.id).to eq(existing_stakeholder.id)
        expect(record.first_name).to eq(test_first_name)
      end
    end
  end

  describe '#perform_additional_operations' do
    let(:stakeholder) { create(:an_stakeholder) }
    let(:entity_data) { { "file_details" => { "acteur" => {} } } }

    context 'when record is persisted' do
      it 'processes addresses' do
        expect_any_instance_of(SaumonNet::AddressProcessor).to receive(:process)

        service.send(:perform_additional_operations, stakeholder, entity_data, :created)
      end

      it 'processes terms' do
        expect_any_instance_of(SaumonNet::TermProcessor).to receive(:process)

        service.send(:perform_additional_operations, stakeholder, entity_data, :created)
      end

      it 'calls sync_search_fields when method is available' do
        allow(stakeholder).to receive(:sync_search_fields)

        service.send(:perform_additional_operations, stakeholder, entity_data, :created)

        expect(stakeholder).to have_received(:sync_search_fields)
      end
    end

    context 'when record is not persisted' do
      let(:new_stakeholder) { build(:an_stakeholder) }

      it 'does not process addresses or terms' do
        expect(SaumonNet::AddressProcessor).not_to receive(:new)
        expect(SaumonNet::TermProcessor).not_to receive(:new)

        service.send(:perform_additional_operations, new_stakeholder, entity_data, :created)
      end
    end
  end

  describe 'integration test' do
    let(:uid) { "PA721860" }
    let(:civility) { "M." }
    let(:first_name) { "Jean-François" }
    let(:last_name) { "Cesarini" }
    let(:birth_date_str) { "1970-09-30" }
    let(:email) { "test@example.com" }
    let(:body_uid) { "PO123456" }
    let(:address_uid) { "ADR123" }
    let(:address_city) { "Paris" }
    let(:term_uid) { "TERM123" }
    let(:legislature) { "16" }
    let(:term_start_date) { "2022-06-22" }

    let(:body) { create(:an_body, uid: body_uid) }
    let(:full_entity_data) do
      {
        "uid" => uid,
        "file_details" => {
          "acteur" => {
            "uid" => { "#text" => uid },
            "etatCivil" => {
              "ident" => {
                "civ" => civility,
                "prenom" => first_name,
                "nom" => last_name
              },
              "infoNaissance" => {
                "dateNais" => birth_date_str
              }
            },
            "adresses" => {
              "adresse" => [
                {
                  "@xsi:type" => "AdresseMail_Type",
                  "valElec" => email
                },
                {
                  "@xsi:type" => "AdressePostale_Type",
                  "uid" => address_uid,
                  "ville" => address_city
                }
              ]
            },
            "mandats" => {
              "mandat" => {
                "uid" => term_uid,
                "organes" => { "organeRef" => body_uid },
                "legislature" => legislature,
                "dateDebut" => term_start_date
              }
            }
          }
        }
      }
    end

    before do
      body
      allow(An::CorrectionApplier).to receive_message_chain(:new, :detect_all, :apply)
    end

    it 'creates stakeholder with all related records' do
      expect {
        service.send(:process_entity, full_entity_data)
      }.to change(An::Stakeholder, :count).by(1)
        .and change(An::StakeholderAddress, :count).by(1)
        .and change(An::Term, :count).by(1)

      stakeholder = An::Stakeholder.find_by_uid(uid)
      expect(stakeholder.emails).to include(email)

      address = An::StakeholderAddress.find_by_uid(address_uid)
      expect(address.an_stakeholder).to eq(stakeholder)

      term = An::Term.find_by_uid(term_uid)
      expect(term.an_stakeholder).to eq(stakeholder)
    end
  end
end
