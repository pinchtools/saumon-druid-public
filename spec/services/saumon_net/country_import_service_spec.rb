require 'rails_helper'

RSpec.describe SaumonNet::CountryImportService do
  let(:service) { described_class.new }

  before do
    allow(SaumonNet).to receive(:configure)
    allow(SaumonNet::HealthMonitoringService).to receive(:record_successful_import)
  end

  describe '#initialize' do
    it 'sets entity_type to "pays"' do
      expect(service.entity_type).to eq("pays")
    end
  end

  describe '#map_entity_attributes' do
    context 'with complete entity data' do
      let(:entity_data) do
        {
          "uid" => "PAYS_123",
          "nomCourant" => "France",
          "code_insee" => "99100",
          "libelleInsee" => "FRANCE",
          "code_iso3A" => "FRA",
          "activ" => "true"
        }
      end

      it 'maps all attributes correctly' do
        result = service.send(:map_entity_attributes, entity_data)

        expect(result).to eq({
          uid: "PAYS_123",
          name: "France",
          insee_code: "99100",
          insee_name: "FRANCE",
          iso_code: "FRA",
          active: true
        })
      end
    end

    context 'with file_details taking precedence' do
      let(:entity_data) do
        {
          "uid" => "PAYS_123",
          "nomCourant" => "Old Name",
          "file_details" => {
            "nomCourant" => "New Name",
            "code_insee" => "99100"
          }
        }
      end

      it 'uses file_details when available' do
        result = service.send(:map_entity_attributes, entity_data)

        expect(result[:name]).to eq("New Name")
        expect(result[:insee_code]).to eq("99100")
      end
    end

    context 'with fallback to libelleANLong for name' do
      let(:entity_data) do
        {
          "uid" => "PAYS_123",
          "libelleANLong" => "République française"
        }
      end

      it 'uses libelleANLong when nomCourant is missing' do
        result = service.send(:map_entity_attributes, entity_data)

        expect(result[:name]).to eq("République française")
      end
    end

    context 'with missing optional fields' do
      let(:entity_data) { { "uid" => "PAYS_123" } }

      it 'handles nil values gracefully' do
        result = service.send(:map_entity_attributes, entity_data)

        expect(result[:uid]).to eq("PAYS_123")
        expect(result[:name]).to be_nil
        expect(result[:insee_code]).to be_nil
        expect(result[:active]).to be true # default for blank
      end
    end
  end

  describe '#find_or_initialize_record' do
    let(:attributes) do
      {
        uid: "PAYS_123",
        name: "France",
        insee_code: "99100",
        active: true
      }
    end

    context 'when country does not exist' do
      it 'creates new country with attributes' do
        country = service.send(:find_or_initialize_record, attributes)

        expect(country).to be_a(An::Country)
        expect(country.uid).to eq("PAYS_123")
        expect(country.name).to eq("France")
      end
    end

    context 'when country exists' do
      let!(:existing_country) { create(:an_country, uid: "PAYS_123", name: "Old France") }

      it 'updates existing country with new attributes' do
        country = service.send(:find_or_initialize_record, attributes)

        expect(country).to eq(existing_country)
        expect(country.name).to eq("France")
        expect(country.insee_code).to eq("99100")
      end
    end
  end

  describe '#parse_boolean' do
    it 'returns true for blank values' do
      expect(service.send(:parse_boolean, nil)).to be true
      expect(service.send(:parse_boolean, "")).to be true
      expect(service.send(:parse_boolean, "   ")).to be true
    end

    it 'parses truthy string values' do
      expect(service.send(:parse_boolean, "true")).to be true
      expect(service.send(:parse_boolean, "TRUE")).to be true
      expect(service.send(:parse_boolean, "1")).to be true
      expect(service.send(:parse_boolean, "yes")).to be true
      expect(service.send(:parse_boolean, "YES")).to be true
    end

    it 'parses falsy string values' do
      expect(service.send(:parse_boolean, "false")).to be false
      expect(service.send(:parse_boolean, "FALSE")).to be false
      expect(service.send(:parse_boolean, "0")).to be false
      expect(service.send(:parse_boolean, "no")).to be false
      expect(service.send(:parse_boolean, "NO")).to be false
    end

    it 'defaults to true for unrecognized values' do
      expect(service.send(:parse_boolean, "maybe")).to be true
      expect(service.send(:parse_boolean, "invalid")).to be true
      expect(service.send(:parse_boolean, 123)).to be true
    end
  end

  describe 'integration test' do
    let(:entity_data) do
      {
        "uid" => "PAYS_FRA",
        "file_details" => {
          "nomCourant" => "France",
          "code_insee" => "99100",
          "libelleInsee" => "FRANCE",
          "code_iso3A" => "FRA",
          "activ" => "true"
        }
      }
    end

    before do
      allow(service).to receive(:parse_file_content).and_return(entity_data)
      allow(service).to receive(:perform_additional_operations)
    end

    it 'creates country record from entity data' do
      expect {
        service.send(:process_entity, entity_data)
      }.to change(An::Country, :count).by(1)

      country = An::Country.find_by(uid: "PAYS_FRA")
      expect(country.name).to eq("France")
      expect(country.insee_code).to eq("99100")
      expect(country.insee_name).to eq("FRANCE")
      expect(country.iso_code).to eq("FRA")
      expect(country.active).to be true
    end

    it 'updates existing country without duplicating' do
      existing = create(:an_country, uid: "PAYS_FRA", name: "Old France")

      expect {
        service.send(:process_entity, entity_data)
      }.not_to change(An::Country, :count)

      existing.reload
      expect(existing.name).to eq("France")
      expect(existing.insee_code).to eq("99100")
    end

    it 'tracks statistics correctly' do
      initial_stats = {
        processed: service.stats.processed,
        created: service.stats.created
      }

      service.send(:process_entity, entity_data)

      expect(service.stats.processed).to eq(initial_stats[:processed] + 1)
      expect(service.stats.created).to eq(initial_stats[:created] + 1)
    end
  end
end
