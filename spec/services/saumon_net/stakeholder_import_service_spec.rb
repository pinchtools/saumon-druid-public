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
    let(:entity_data) do
      {
        "uid" => "PA721860",
        "file_details" => {
          "acteur" => {
            "uid" => { "#text" => "PA721860" },
            "etatCivil" => {
              "ident" => {
                "civ" => "M.",
                "prenom" => "Jean-François",
                "nom" => "Cesarini"
              },
              "infoNaissance" => {
                "dateNais" => "1970-09-30",
                "villeNais" => "Avignon",
                "depNais" => "Vaucluse",
                "paysNais" => "France"
              },
              "dateDeces" => "2020-03-29"
            },
            "profession" => {
              "libelleCourant" => "Industriel-Chef d'entreprise",
              "socProcINSEE" => {
                "catSocPro" => "Chefs d'entreprise de 10 salariés ou plus",
                "famSocPro" => "Artisans, commerçants et chefs d'entreprise"
              }
            }
          }
        }
      }
    end

    it 'maps entity attributes correctly' do
      result = service.send(:map_entity_attributes, entity_data)

      expect(result).to include(
        uid: "PA721860",
        civility: "M.",
        gender: "male",
        first_name: "Jean-François",
        last_name: "Cesarini",
        birth_date: Date.parse("1970-09-30"),
        birth_city: "Avignon",
        birth_province: "Vaucluse",
        birth_country: "France",
        death_date: Date.parse("2020-03-29"),
        occupation: "Industriel-Chef d'entreprise",
        occupation_category: "Chefs d'entreprise de 10 salariés ou plus",
        occupation_family: "Artisans, commerçants et chefs d'entreprise",
        emails: [],
        urls: [],
        phone_numbers: []
      )
    end

    context 'with minimal data' do
      let(:minimal_entity_data) do
        {
          "uid" => "PA123456",
          "file_details" => {
            "acteur" => {
              "uid" => { "#text" => "PA123456" },
              "etatCivil" => {
                "ident" => {
                  "prenom" => "John",
                  "nom" => "Doe"
                }
              }
            }
          }
        }
      end

      it 'handles minimal data gracefully' do
        result = service.send(:map_entity_attributes, minimal_entity_data)

        expect(result).to include(
          uid: "PA123456",
          first_name: "John",
          last_name: "Doe",
          civility: nil,
          birth_date: nil,
          death_date: nil
        )
      end
    end
  end

  describe '#find_or_initialize_record' do
    let(:attributes) { { uid: "PA123456", first_name: "john", last_name: "doe" } }

    context 'when stakeholder does not exist' do
      it 'creates a new stakeholder' do
        stakeholder = service.send(:find_or_initialize_record, attributes)

        expect(stakeholder).to be_new_record
        expect(stakeholder.uid).to eq("PA123456")
        expect(stakeholder.first_name).to eq("john")
        expect(stakeholder.last_name).to eq("doe")
      end
    end

    context 'when stakeholder exists' do
      let!(:existing_stakeholder) { create(:an_stakeholder, uid: "PA123456", first_name: "Jane") }

      it 'finds and updates the existing stakeholder' do
        stakeholder = service.send(:find_or_initialize_record, attributes)

        expect(stakeholder).to eq(existing_stakeholder)
        expect(stakeholder.first_name).to eq("john")  # Updated
        expect(stakeholder.last_name).to eq("doe")
      end
    end
  end

  describe '#upsert_stakeholder_addresses' do
    let(:stakeholder) { create(:an_stakeholder, uid: "PA123456") }
    let(:entity_data) do
      {
        "file_details" => {
          "acteur" => {
            "adresses" => {
              "adresse" => [
                {
                  "@xsi:type" => "AdressePostale_Type",
                  "uid" => "AD123456",
                  "intitule" => "Assemblée nationale",
                  "numeroRue" => "126",
                  "nomRue" => "Rue de l'Université",
                  "codePostal" => "75355",
                  "ville" => "Paris 07 SP",
                  "poids" => "1"
                },
                {
                  "@xsi:type" => "AdresseMail_Type",
                  "uid" => "AD123457",
                  "valElec" => "test@assemblee-nationale.fr"
                },
                {
                  "@xsi:type" => "AdresseSiteWeb_Type",
                  "uid" => "AD123458",
                  "typeLibelle" => "Facebook",
                  "valElec" => "Jean-Francois-Cesarini-Souad-Zitouni-1960230264254661"
                },
                {
                  "@xsi:type" => "AdresseTelephonique_Type",
                  "uid" => "AD123459",
                  "numeroTelephone" => "01.40.63.12.34"
                }
              ]
            }
          }
        }
      }
    end

    it 'creates postal address records and updates stakeholder contact arrays' do
      expect {
        service.send(:upsert_stakeholder_addresses, stakeholder, entity_data)
      }.to change(An::StakeholderAddress, :count).by(1)

      address = An::StakeholderAddress.last
      expect(address.uid).to eq("AD123456")
      expect(address.address_1).to eq("Assemblée nationale")
      expect(address.street_number).to eq("126")
      expect(address.street_name).to eq("Rue de l'Université")

      stakeholder.reload
      expect(stakeholder.emails).to include("test@assemblee-nationale.fr")
      expect(stakeholder.urls).to include("https://facebook.com/Jean-Francois-Cesarini-Souad-Zitouni-1960230264254661")
      expect(stakeholder.phone_numbers).to include("01.40.63.12.34")
    end

    it 'handles upsert mode by merging contact arrays' do
      stakeholder.update!(emails: [ "existing@email.com" ], urls: [ "https://existing.com" ], phone_numbers: [ "01.23.45.67.89" ])

      service.send(:upsert_stakeholder_addresses, stakeholder, entity_data)

      stakeholder.reload
      expect(stakeholder.emails).to include("existing@email.com", "test@assemblee-nationale.fr")
      expect(stakeholder.urls).to include("https://existing.com", "https://facebook.com/Jean-Francois-Cesarini-Souad-Zitouni-1960230264254661")
      expect(stakeholder.phone_numbers).to include("01.23.45.67.89", "01.40.63.12.34")
    end
  end

  describe '#upsert_terms' do
    let(:stakeholder) { create(:an_stakeholder, uid: "PA123456") }
    let(:body) { create(:an_body, uid: "PO123456") }
    let(:entity_data) do
      {
        "file_details" => {
          "acteur" => {
            "mandats" => {
              "mandat" => [
                {
                  "@xsi:type" => "MandatSimple_Type",
                  "uid" => "PM123456",
                  "typeOrgane" => "GP",
                  "dateDebut" => "2017-06-27",
                  "dateFin" => "2020-03-29",
                  "legislature" => "15",
                  "preseance" => "20",
                  "nominPrincipale" => "1",
                  "organes" => { "organeRef" => "PO123456" },
                  "infosQualite" => {
                    "codeQualite" => "Membre",
                    "libQualite" => "Membre",
                    "libQualiteSex" => "Membre"
                  },
                  "collaborateurs" => {
                    "collaborateur" => [
                      {
                        "qualite" => "M.",
                        "prenom" => "Alexis",
                        "nom" => "David"
                      },
                      {
                        "qualite" => "M.",
                        "prenom" => "Baptiste",
                        "nom" => "Al Sabty"
                      }
                    ]
                  }
                }
              ]
            }
          }
        }
      }
    end

    before do
      allow(service).to receive(:find_body_by_uid).with("PO123456").and_return(body)
    end

    it 'creates term records with correct attributes' do
      expect {
        service.send(:upsert_terms, stakeholder, entity_data)
      }.to change(An::Term, :count).by(1)

      term = An::Term.last
      expect(term.uid).to eq("PM123456")
      expect(term.label).to eq("Member CIRCO")
      expect(term.an_stakeholder).to eq(stakeholder)
      expect(term.an_body).to eq(body)
      expect(term.legislature).to eq("15")
      expect(term.main).to be(true)
      expect(term.start_date).to eq(DateTime.parse("2017-06-27"))
      expect(term.end_date).to eq(DateTime.parse("2020-03-29"))
      expect(term.collaborators).to eq([ "M. Alexis David", "M. Baptiste Al Sabty" ])
      expect(term.role_rank).to eq(20)
      expect(term.capacity).to eq("membre")
    end

    context 'with parliamentary mandate' do
      let(:constituency) { create(:an_body, uid: "PO654321") }
      let(:parliamentary_entity_data) do
        {
          "file_details" => {
            "acteur" => {
              "mandats" => {
                "mandat" => [
                  {
                    "@xsi:type" => "MandatParlementaire_type",
                    "uid" => "PM654321",
                    "typeOrgane" => "ASSEMBLEE",
                    "dateDebut" => "2017-06-18",
                    "legislature" => "15",
                    "nominPrincipale" => "1",
                    "organes" => { "organeRef" => "PO123456" },
                    "election" => {
                      "refCirconscription" => "PO654321",
                      "causeMandat" => "élections générales",
                      "lieu" => {
                        "numDepartement" => "84",
                        "numCirco" => "1"
                      }
                    },
                    "mandature" => {
                      "datePriseFonction" => "2017-06-21",
                      "causeFin" => "Décès",
                      "placeHemicycle" => "84",
                      "mandatRemplaceRef" => "PM123456"
                    }
                  }
                ]
              }
            }
          }
        }
      end

      before do
        allow(service).to receive(:find_body_by_uid).with("PO654321").and_return(constituency)
      end

      it 'handles parliamentary mandate attributes correctly' do
        service.send(:upsert_terms, stakeholder, parliamentary_entity_data)

        term = An::Term.last
        expect(term.constituency).to eq(constituency)
        expect(term.assumption_date).to eq(DateTime.parse("2017-06-21"))
        expect(term.origin).to eq("élections générales")
        expect(term.end_reason).to eq("Décès")
        expect(term.seat).to eq("84")
      end

      context 'with mandatRemplaceRef' do
        let!(:replaced_term) { create(:an_term, uid: "PM123456") }

        it 'associates the replaced deputy term' do
          service.send(:upsert_terms, stakeholder, parliamentary_entity_data)

          term = An::Term.last
          expect(term.deputy_term).to eq(replaced_term)
        end
      end

      context 'without mandatRemplaceRef' do
        let(:parliamentary_entity_without_ref) do
          data = parliamentary_entity_data.deep_dup
          data["file_details"]["acteur"]["mandats"]["mandat"][0]["mandature"].delete("mandatRemplaceRef")
          data
        end

        it 'sets deputy_term to nil when mandatRemplaceRef is not present' do
          service.send(:upsert_terms, stakeholder, parliamentary_entity_without_ref)

          term = An::Term.last
          expect(term.deputy_term).to be_nil
        end
      end
    end

    context 'correction detection' do
      it 'calls detect_and_apply_corrections for each term' do
        expect(service).to receive(:detect_and_apply_corrections).once

        service.send(:upsert_terms, stakeholder, entity_data)
      end
    end
  end

  describe 'helper methods' do
    describe '#extract_file_uid' do
      it 'extracts UID from hash format' do
        acteur_data = { "uid" => { "#text" => "PA123456" } }

        result = service.send(:extract_file_uid, acteur_data)
        expect(result).to eq("PA123456")
      end

      it 'extracts UID from string format' do
        acteur_data = { "uid" => "PA123456" }

        result = service.send(:extract_file_uid, acteur_data)
        expect(result).to eq("PA123456")
      end

      it 'returns nil for missing UID' do
        acteur_data = {}

        result = service.send(:extract_file_uid, acteur_data)
        expect(result).to be_nil
      end

      it 'returns nil for invalid UID format' do
        acteur_data = { "uid" => 123 }

        result = service.send(:extract_file_uid, acteur_data)
        expect(result).to be_nil
      end
    end

    describe '#build_website_url' do
      it 'handles Facebook type by prepending Facebook URL' do
        address_data = {
          "typeLibelle" => "Facebook",
          "valElec" => "jean-francois-cesarini-profile"
        }

        result = service.send(:build_website_url, address_data)
        expect(result).to eq("https://facebook.com/jean-francois-cesarini-profile")
      end

      it 'handles Facebook type case insensitively' do
        address_data = {
          "typeLibelle" => "FACEBOOK",
          "valElec" => "test-profile"
        }

        result = service.send(:build_website_url, address_data)
        expect(result).to eq("https://facebook.com/test-profile")
      end

      it 'returns original valElec for non-Facebook types' do
        address_data = {
          "typeLibelle" => "Twitter",
          "valElec" => "@test"
        }

        result = service.send(:build_website_url, address_data)
        expect(result).to eq("https://twitter.com/@test")
      end

      it 'returns original valElec when typeLibelle is missing' do
        address_data = {
          "valElec" => "https://example.com"
        }

        result = service.send(:build_website_url, address_data)
        expect(result).to eq("https://example.com")
      end
    end

    describe '#parse_date' do
      it 'parses valid date strings' do
        result = service.send(:parse_date, "1970-09-30")
        expect(result).to eq(Date.parse("1970-09-30"))
      end

      it 'returns nil for blank dates' do
        result = service.send(:parse_date, "")
        expect(result).to be_nil
      end

      it 'logs warning and returns nil for invalid dates' do
        expect(service).to receive(:logger).and_return(double(warn: nil))

        result = service.send(:parse_date, "invalid-date")
        expect(result).to be_nil
      end
    end
  end

  describe '#perform_additional_operations' do
    let(:stakeholder) { create(:an_stakeholder) }
    let(:entity_data) do
      {
        "file_details" => {
          "acteur" => {
            "adresses" => {},
            "mandats" => {}
          }
        }
      }
    end

    before do
      allow(service).to receive(:upsert_stakeholder_addresses)
      allow(service).to receive(:upsert_terms)
    end

    context 'when record has sync_search_fields method' do
      it 'calls sync_search_fields on the record' do
        expect(stakeholder).to receive(:sync_search_fields)

        service.send(:perform_additional_operations, stakeholder, entity_data, :create)
      end
    end

    context 'when record does not have sync_search_fields method' do
      let(:record_without_sync) { double('Record', persisted?: true) }

      it 'does not raise an error' do
        expect {
          service.send(:perform_additional_operations, record_without_sync, entity_data, :create)
        }.not_to raise_error
      end
    end

    context 'when record is not persisted' do
      let(:unpersisted_stakeholder) { build(:an_stakeholder) }

      it 'does not call sync_search_fields' do
        expect(unpersisted_stakeholder).not_to receive(:sync_search_fields)

        service.send(:perform_additional_operations, unpersisted_stakeholder, entity_data, :create)
      end
    end
  end

  describe '#detect_and_apply_corrections' do
    let(:stakeholder) { create(:an_stakeholder) }
    let(:body) { create(:an_body) }
    let!(:new_term) do
      create(:an_term,
             uid: "PM_NEW_123",
             an_stakeholder: stakeholder,
             an_body: body,
             capacity: "president")
    end

    context 'when record is newly created' do
      let(:mock_detector) { instance_double(An::CorrectionDetector) }
      let(:corrections_data) do
        [
          {
            correction_changes: {
              "capacity" => {
                "before" => "president",
                "after" => "president-du-senat"
              }
            },
            reason: "Test correction reason",
            correction_type: "automatic",
            session_id: service.session_id
          }
        ]
      end

      before do
        allow(An::CorrectionDetector).to receive(:new).and_return(mock_detector)
        allow(mock_detector).to receive(:detect_all).and_return(corrections_data)
      end

      it 'applies corrections to newly created records' do
        expect {
          service.send(:detect_and_apply_corrections, new_term)
        }.to change(An::Correction, :count).by(1)

        correction = An::Correction.last
        expect(correction.correctable).to eq(new_term)
        expect(correction.correction_changes).to eq({
          "capacity" => {
            "before" => "president",
            "after" => "president-du-senat"
          }
        })
        expect(correction.reason).to eq("Test correction reason")
        expect(correction.correction_type).to eq("automatic")
      end

      it 'calls the detector for newly created records' do
        expect(An::CorrectionDetector).to receive(:new).
          with(new_term, session_id: service.session_id).
          and_return(mock_detector)

        service.send(:detect_and_apply_corrections, new_term)
      end
    end

    context 'when record already existed (not newly created)' do
      let(:existing_term) { create(:an_term, an_stakeholder: stakeholder, an_body: body, capacity: "president") }

      before do
        # Update an existing term to ensure previously_new_record? == false
        existing_term.update!(capacity: "membre")
      end

      it 'does not apply corrections to existing records' do
        expect(An::CorrectionDetector).not_to receive(:new)

        expect {
          service.send(:detect_and_apply_corrections, existing_term)
        }.not_to change(An::Correction, :count)
      end
    end

    context 'when multiple corrections are detected for new record' do
      let(:mock_detector) { instance_double(An::CorrectionDetector) }
      let(:corrections_data) do
        [
          {
            correction_changes: {
              "capacity" => {
                "before" => "president",
                "after" => "president-du-senat"
              }
            },
            reason: "First correction",
            correction_type: "automatic",
            session_id: service.session_id
          },
          {
            correction_changes: {
              "end_date" => {
                "before" => nil,
                "after" => "2024-01-01"
              }
            },
            reason: "Second correction",
            correction_type: "automatic",
            session_id: service.session_id
          }
        ]
      end

      before do
        allow(An::CorrectionDetector).to receive(:new).and_return(mock_detector)
        allow(mock_detector).to receive(:detect_all).and_return(corrections_data)
      end

      it 'creates all correction records' do
        expect {
          service.send(:detect_and_apply_corrections, new_term)
        }.to change(An::Correction, :count).by(2)

        corrections = An::Correction.where(correctable: new_term)
        expect(corrections.count).to eq(2)
        expect(corrections.pluck(:reason)).to contain_exactly("First correction", "Second correction")
      end
    end

    context 'when no corrections are detected for new record' do
      let(:mock_detector) { instance_double(An::CorrectionDetector) }

      before do
        allow(An::CorrectionDetector).to receive(:new).and_return(mock_detector)
        allow(mock_detector).to receive(:detect_all).and_return([])
      end

      it 'does not create any correction records' do
        expect {
          service.send(:detect_and_apply_corrections, new_term)
        }.not_to change(An::Correction, :count)
      end
    end
  end

  describe '#upsert_substitutes' do
    let(:stakeholder) { create(:an_stakeholder) }
    let(:term) { create(:an_term, an_stakeholder: stakeholder) }
    let(:substitute_stakeholder) { create(:an_stakeholder) }
    let(:mandate_data) do
      {
        "suppleants" => {
          "suppleant" => {
            "dateDebut" => "2022-06-19",
            "dateFin" => "2027-06-19",
            "suppleantRef" => substitute_stakeholder.uid
          }
        }
      }
    end

    it 'creates a substitute when valid data is provided' do
      expect {
        service.send(:upsert_substitutes, term, mandate_data)
      }.to change(An::Substitute, :count).by(1)

      substitute = An::Substitute.last
      expect(substitute.an_term).to eq(term)
      expect(substitute.an_stakeholder).to eq(substitute_stakeholder)
      expect(substitute.start_date).to eq(DateTime.parse("2022-06-19"))
      expect(substitute.end_date).to eq(DateTime.parse("2027-06-19"))
    end

    it 'handles multiple substitutes' do
      substitute_stakeholder_2 = create(:an_stakeholder)
      mandate_data["suppleants"]["suppleant"] = [
        {
          "dateDebut" => "2022-06-19",
          "dateFin" => "2024-06-19",
          "suppleantRef" => substitute_stakeholder.uid
        },
        {
          "dateDebut" => "2024-06-20",
          "dateFin" => "2027-06-19",
          "suppleantRef" => substitute_stakeholder_2.uid
        }
      ]

      expect {
        service.send(:upsert_substitutes, term, mandate_data)
      }.to change(An::Substitute, :count).by(2)
    end

    it 'does not create duplicate substitutes for same term, stakeholder, and start_date' do
      service.send(:upsert_substitutes, term, mandate_data)

      expect {
        service.send(:upsert_substitutes, term, mandate_data)
      }.not_to change(An::Substitute, :count)
    end

    it 'creates different substitutes for same term and stakeholder with different start_dates' do
      service.send(:upsert_substitutes, term, mandate_data)

      mandate_data["suppleants"]["suppleant"]["dateDebut"] = "2025-01-01"

      expect {
        service.send(:upsert_substitutes, term, mandate_data)
      }.to change(An::Substitute, :count).by(1)
    end

    it 'skips when stakeholder is not found' do
      mandate_data["suppleants"]["suppleant"]["suppleantRef"] = "INVALID_UID"

      expect {
        service.send(:upsert_substitutes, term, mandate_data)
      }.not_to change(An::Substitute, :count)
    end

    it 'returns early when no suppleants data' do
      mandate_data.delete("suppleants")

      expect {
        service.send(:upsert_substitutes, term, mandate_data)
      }.not_to change(An::Substitute, :count)
    end
  end
end
