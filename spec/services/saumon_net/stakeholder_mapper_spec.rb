require 'rails_helper'

RSpec.describe SaumonNet::StakeholderMapper do
  describe '#map_attributes' do
    let(:uid) { "PA721860" }
    let(:civility) { "M." }
    let(:first_name) { "Jean-François" }
    let(:last_name) { "Cesarini" }
    let(:birth_date) { "1970-09-30" }
    let(:birth_city) { "Avignon" }
    let(:birth_province) { "Vaucluse" }
    let(:birth_country) { "France" }
    let(:death_date) { "2020-03-29" }
    let(:occupation) { "Industriel-Chef d'entreprise" }
    let(:occupation_category) { "Chefs d'entreprise de 10 salariés ou plus" }
    let(:occupation_family) { "Artisans, commerçants et chefs d'entreprise" }

    let(:full_acteur_data) do
      {
        "uid" => { "#text" => uid },
        "etatCivil" => {
          "ident" => {
            "civ" => civility,
            "prenom" => first_name,
            "nom" => last_name
          },
          "infoNaissance" => {
            "dateNais" => birth_date,
            "villeNais" => birth_city,
            "depNais" => birth_province,
            "paysNais" => birth_country
          },
          "dateDeces" => death_date
        },
        "profession" => {
          "libelleCourant" => occupation,
          "socProcINSEE" => {
            "catSocPro" => occupation_category,
            "famSocPro" => occupation_family
          }
        }
      }
    end

    it 'maps all attributes correctly' do
      mapper = described_class.new(full_acteur_data)
      result = mapper.map_attributes

      expect(result).to include(
        uid: uid,
        civility: civility,
        gender: "male",
        first_name: first_name,
        last_name: last_name,
        birth_date: Date.parse(birth_date),
        birth_city: birth_city,
        birth_province: birth_province,
        birth_country: birth_country,
        death_date: Date.parse(death_date),
        occupation: occupation,
        occupation_category: occupation_category,
        occupation_family: occupation_family,
        emails: [],
        urls: [],
        phone_numbers: []
      )
    end

    context 'UID extraction' do
      let(:test_uid) { "PA123456" }

      it 'extracts UID from hash format' do
        acteur_data = { "uid" => { "#text" => test_uid } }
        mapper = described_class.new(acteur_data)
        result = mapper.map_attributes

        expect(result[:uid]).to eq(test_uid)
      end

      it 'extracts UID from string format' do
        acteur_data = { "uid" => test_uid }
        mapper = described_class.new(acteur_data)
        result = mapper.map_attributes

        expect(result[:uid]).to eq(test_uid)
      end

      it 'returns nil for missing UID' do
        acteur_data = {}
        mapper = described_class.new(acteur_data)
        result = mapper.map_attributes

        expect(result[:uid]).to be_nil
      end

      it 'returns nil for invalid UID format' do
        acteur_data = { "uid" => 123 }
        mapper = described_class.new(acteur_data)
        result = mapper.map_attributes

        expect(result[:uid]).to be_nil
      end
    end

    context 'gender determination' do
      let(:male_civility) { "M." }
      let(:female_civility) { "Mme" }

      it 'sets gender to male for "M." civility' do
        acteur_data = {
          "etatCivil" => {
            "ident" => { "civ" => male_civility }
          }
        }
        mapper = described_class.new(acteur_data)
        result = mapper.map_attributes

        expect(result[:gender]).to eq("male")
      end

      it 'sets gender to female for non-"M." civility' do
        acteur_data = {
          "etatCivil" => {
            "ident" => { "civ" => female_civility }
          }
        }
        mapper = described_class.new(acteur_data)
        result = mapper.map_attributes

        expect(result[:gender]).to eq("female")
      end
    end
  end
end
