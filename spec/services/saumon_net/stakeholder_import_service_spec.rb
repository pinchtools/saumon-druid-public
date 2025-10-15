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
    let(:attributes) { { uid: "PA123456", first_name: "John", last_name: "Doe" } }

    context 'when stakeholder does not exist' do
      it 'creates a new stakeholder' do
        stakeholder = service.send(:find_or_initialize_record, attributes)

        expect(stakeholder).to be_new_record
        expect(stakeholder.uid).to eq("PA123456")
        expect(stakeholder.first_name).to eq("John")
        expect(stakeholder.last_name).to eq("Doe")
      end
    end

    context 'when stakeholder exists' do
      let!(:existing_stakeholder) { create(:an_stakeholder, uid: "PA123456", first_name: "Jane") }

      it 'finds and updates the existing stakeholder' do
        stakeholder = service.send(:find_or_initialize_record, attributes)

        expect(stakeholder).to eq(existing_stakeholder)
        expect(stakeholder.first_name).to eq("John")  # Updated
        expect(stakeholder.last_name).to eq("Doe")
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
      expect(term.an_stakeholder).to eq(stakeholder)
      expect(term.an_body).to eq(body)
      expect(term.role_code).to eq("GP")
      expect(term.legislature).to eq("15")
      expect(term.main).to be(true)
      expect(term.start_date).to eq(DateTime.parse("2017-06-27"))
      expect(term.end_date).to eq(DateTime.parse("2020-03-29"))
      expect(term.collaborators).to eq([ "M. Alexis David", "M. Baptiste Al Sabty" ])
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
end
