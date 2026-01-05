require 'rails_helper'

RSpec.describe SaumonNet::BodyImportService do
  let(:service) { described_class.new }

  before do
    allow(SaumonNet).to receive(:configure)
    allow(SaumonNet::HealthMonitoringService).to receive(:record_successful_import)
  end

  describe '#initialize' do
    it 'sets entity_type to "organe"' do
      expect(service.entity_type).to eq("organe")
    end
  end

  describe '#map_entity_attributes' do
    let(:body_type) { create(:an_body_type, code: "AN") }
    let(:parent_body) { create(:an_body, uid: "PARENT_123") }

    let(:entity_data) do
      {
        "uid" => "ANOD_ORGANE_123",
        "file_details" => {
          "uid" => "ORGANE_123",
          "libelle" => "Assemblée nationale",
          "libelleAbrev" => "AN",
          "libelleEdition" => "AN-XV",
          "codeType" => "AN",
          "organeParent" => "PARENT_123",
          "viMoDe" => {
            "dateDebut" => "2022-06-28",
            "dateFin" => "2027-06-21",
            "dateAgrement" => "2022-06-22"
          },
          "chambre" => "1",
          "regime" => "5ème République",
          "legislature" => "XVI",
          "numero" => "1",
          "lieu" => {
            "region" => { "libelle" => "Île-de-France" },
            "departement" => { "code" => "75" }
          }
        }
      }
    end

    before do
      allow(service).to receive(:find_or_create_body_type).and_return(body_type)
      allow(service).to receive(:find_parent_body).and_return(parent_body)
    end

    it 'maps all attributes correctly' do
      result = service.send(:map_entity_attributes, entity_data)

      expect(result).to include({
        uid: "ORGANE_123",
        an_body_type: body_type,
        parent: parent_body,
        label: "Assemblée nationale",
        label_abbr: "AN",
        label_code: "AN-XV",
        start_date: Date.parse("2022-06-28"),
        end_date: Date.parse("2027-06-21"),
        deliver_date: Date.parse("2022-06-22"),
        chamber: "1",
        regime: "5ème République",
        legislature: "XVI",
        number: "1",
        province: "Île-de-France",
        department_code: "75"
      })
    end

    context 'with missing viMoDe data' do
      let(:entity_data) do
        {
          "uid" => "ORGANE_123",
          "file_details" => {
            "libelle" => "Test Body",
            "codeType" => "TEST"
          }
        }
      end

      it 'handles missing date fields' do
        result = service.send(:map_entity_attributes, entity_data)

        expect(result[:start_date]).to be_nil
        expect(result[:end_date]).to be_nil
        expect(result[:deliver_date]).to be_nil
      end
    end
  end

  describe '#find_or_create_body_type' do
    let(:file_details) { { "codeType" => "AN" } }

    context 'when body type exists' do
      let!(:existing_type) { create(:an_body_type, code: "AN") }

      it 'returns existing body type' do
        result = service.send(:find_or_create_body_type, file_details)
        expect(result).to eq(existing_type)
      end
    end

    context 'when body type does not exist' do
      it 'creates new body type' do
        expect {
          service.send(:find_or_create_body_type, file_details)
        }.to change(An::BodyType, :count).by(1)

        body_type = An::BodyType.find_by(code: "AN")
        expect(body_type).to be_present
      end

      it 'logs warning for unknown type' do
        allow(Rails.logger).to receive(:warn)

        service.send(:find_or_create_body_type, file_details)

        expect(Rails.logger).to have_received(:warn).with(
          hash_including(
            message: "Unknown body type code",
            code: "AN"
          )
        )
      end
    end

    context 'with invalid code type' do
      let(:file_details) { { "codeType" => nil } }

      it 'creates UNKNOWN type for nil code' do
        result = service.send(:find_or_create_body_type, file_details)
        expect(result.code).to eq("UNKNOWN")
      end
    end
  end

  describe '#find_parent_body' do
    let!(:parent_body) { create(:an_body, uid: "PARENT_123") }

    context 'when parent UID exists' do
      let(:file_details) { { "organeParent" => "PARENT_123" } }

      it 'returns parent body' do
        result = service.send(:find_parent_body, file_details)
        expect(result).to eq(parent_body)
      end
    end

    context 'when parent UID does not exist' do
      let(:file_details) { { "organeParent" => "NONEXISTENT" } }

      it 'returns nil' do
        result = service.send(:find_parent_body, file_details)
        expect(result).to be_nil
      end
    end

    context 'when parent UID is blank' do
      let(:file_details) { { "organeParent" => "" } }

      it 'returns nil' do
        result = service.send(:find_parent_body, file_details)
        expect(result).to be_nil
      end
    end
  end

  describe '#parse_date' do
    it 'parses valid date strings' do
      result = service.send(:parse_date, "2022-06-28")
      expect(result).to eq(Date.new(2022, 6, 28))
    end

    it 'returns nil for blank dates' do
      expect(service.send(:parse_date, nil)).to be_nil
      expect(service.send(:parse_date, "")).to be_nil
    end

    it 'logs warning and returns nil for invalid dates' do
      allow(Rails.logger).to receive(:warn)

      result = service.send(:parse_date, "invalid-date")

      expect(result).to be_nil
      expect(Rails.logger).to have_received(:warn).with(
        hash_including(
          message: "Failed to parse date",
          date_string: "invalid-date"
        )
      )
    end
  end

  describe '#create_country_association' do
    let(:body) { create(:an_body) }
    let(:country) { create(:an_country, uid: "PAYS_FRA") }
    let(:entity_data) do
      {
        "file_details" => {
          "listePays" => {
            "paysRef" => "PAYS_FRA"
          }
        }
      }
    end

    context 'when country exists' do
      before { country }

      it 'associates country with body' do
        expect {
          service.send(:create_country_association, body, entity_data)
        }.to change { body.an_countries.count }.by(1)

        expect(body.an_countries).to include(country)
      end

      it 'does not duplicate association' do
        body.an_countries << country

        expect {
          service.send(:create_country_association, body, entity_data)
        }.not_to change { body.an_countries.count }
      end

      it 'logs successful association' do
        allow(Rails.logger).to receive(:debug)

        service.send(:create_country_association, body, entity_data)

        expect(Rails.logger).to have_received(:debug).with(
          hash_including(
            message: "Associated country with body",
            country_uid: "PAYS_FRA"
          )
        )
      end
    end

    context 'when country does not exist' do
      it 'logs warning' do
        allow(Rails.logger).to receive(:warn)

        service.send(:create_country_association, body, entity_data)

        expect(Rails.logger).to have_received(:warn).with(
          hash_including(
            message: "Country not found for pays_ref",
            pays_ref: "PAYS_FRA"
          )
        )
      end
    end

    context 'when no pays_ref provided' do
      let(:entity_data) { { "file_details" => {} } }

      it 'does nothing' do
        expect {
          service.send(:create_country_association, body, entity_data)
        }.not_to change { body.an_countries.count }
      end
    end

    context 'when association fails' do
      let(:error) { ActiveRecord::RecordInvalid.new }

      before do
        country
        allow(body).to receive(:an_countries).and_raise(error)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error' do
        service.send(:create_country_association, body, entity_data)

        expect(Rails.logger).to have_received(:error).with(
          hash_including(
            message: "Failed to create country association",
            error: error.message
          )
        )
      end
    end
  end

  describe 'integration test' do
    let(:body_type) { create(:an_body_type, code: "AN") }
    let(:country) { create(:an_country, uid: "PAYS_FRA") }

    let(:entity_data) do
      {
        "uid" => "ANOD_ORGANE_AN",
        "file_details" => {
          "uid" => "ORGANE_AN",
          "libelle" => "Assemblée nationale",
          "codeType" => "AN",
          "viMoDe" => {
            "dateDebut" => "2022-06-28"
          },
          "listePays" => {
            "paysRef" => "PAYS_FRA"
          }
        }
      }
    end

    before do
      body_type
      country
      allow(service).to receive(:parse_file_content).and_return(entity_data)
    end

    it 'creates body with all associations' do
      expect {
        service.send(:process_entity, entity_data)
      }.to change(An::Body, :count).by(1)

      body = An::Body.find_by(uid: "ORGANE_AN")
      expect(body.label).to eq("Assemblée nationale")
      expect(body.an_body_type).to eq(body_type)
      expect(body.start_date).to eq(Date.parse("2022-06-28"))
      expect(body.an_countries).to include(country)
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

  describe '#extract_file_uid' do
    it 'extracts UID from hash format' do
      file_details = { "uid" => { "#text" => "PO123456" } }

      result = service.send(:extract_file_uid, file_details)
      expect(result).to eq("PO123456")
    end

    it 'extracts UID from string format' do
      file_details = { "uid" => "PO123456" }

      result = service.send(:extract_file_uid, file_details)
      expect(result).to eq("PO123456")
    end

    it 'returns nil for missing UID' do
      file_details = {}

      result = service.send(:extract_file_uid, file_details)
      expect(result).to be_nil
    end

    it 'returns nil for invalid UID format' do
      file_details = { "uid" => 123 }

      result = service.send(:extract_file_uid, file_details)
      expect(result).to be_nil
    end
  end

  describe '#find_political_camp' do
    it 'returns camp for known label_abbr' do
      result = service.send(:find_political_camp, "SOC")
      expect(result).to eq("left")
    end

    it 'returns camp for another known label_abbr' do
      result = service.send(:find_political_camp, "RN")
      expect(result).to eq("far_right")
    end

    it 'returns nil for unknown label_abbr' do
      result = service.send(:find_political_camp, "UNKNOWN_ABBR")
      expect(result).to be_nil
    end

    it 'returns nil for blank label_abbr' do
      expect(service.send(:find_political_camp, nil)).to be_nil
      expect(service.send(:find_political_camp, "")).to be_nil
    end
  end

  describe '#political_camp_mapping' do
    it 'loads and indexes config by label_abbr' do
      mapping = service.send(:political_camp_mapping)

      expect(mapping).to be_a(Hash)
      expect(mapping["SOC"]).to include(camp: "left")
      expect(mapping["RN"]).to include(camp: "far_right")
      expect(mapping["LR"]).to include(camp: "right")
    end

    it 'memoizes the mapping' do
      first_call = service.send(:political_camp_mapping)
      second_call = service.send(:political_camp_mapping)

      expect(first_call).to be(second_call)
    end
  end

  describe 'political_camp in map_entity_attributes' do
    let(:body_type) { create(:an_body_type, code: "GP") }

    before do
      allow(service).to receive(:find_or_create_body_type).and_return(body_type)
      allow(service).to receive(:find_parent_body).and_return(nil)
    end

    context 'when label_abbr matches a political group' do
      let(:entity_data) do
        {
          "file_details" => {
            "uid" => "ORGANE_GP_SOC",
            "libelle" => "Socialiste",
            "libelleAbrev" => "SOC",
            "codeType" => "GP"
          }
        }
      end

      it 'sets political_camp from config' do
        result = service.send(:map_entity_attributes, entity_data)

        expect(result[:political_camp]).to eq("left")
      end
    end

    context 'when label_abbr does not match any political group' do
      let(:entity_data) do
        {
          "file_details" => {
            "uid" => "ORGANE_AN",
            "libelle" => "Assemblée nationale",
            "libelleAbrev" => "AN",
            "codeType" => "AN"
          }
        }
      end

      it 'sets political_camp to nil' do
        result = service.send(:map_entity_attributes, entity_data)

        expect(result[:political_camp]).to be_nil
      end
    end
  end
end
