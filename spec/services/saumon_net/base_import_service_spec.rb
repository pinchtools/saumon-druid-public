require 'rails_helper'

RSpec.describe SaumonNet::BaseImportService do
  let(:entity_type) { "test_entity" }
  let(:service) { described_class.new(entity_type) }

  before do
    allow(SaumonNet).to receive(:configure)
    allow(SaumonNet::HealthMonitoringService).to receive(:record_successful_import)
  end

  describe '#initialize' do
    it 'initializes with correct attributes' do
      expect(service.entity_type).to eq(entity_type)
      expect(service.session_id).to match(/\A[0-9a-f-]{36}\z/)
      expect(service.stats).to be_a(SaumonNet::BaseImportService::ImportStats)
    end
  end

  describe '#process_entity' do
    let(:entity_data) { { "uid" => "123", "name" => "Test Entity" } }
    let(:enhanced_data) { entity_data.merge("file_details" => { "additional" => "data" }) }
    let(:mapped_attributes) { { uid: "123", name: "Test Entity" } }

    before do
      allow(service).to receive(:parse_file_content).and_return(enhanced_data)
      allow(service).to receive(:map_entity_attributes).and_return(mapped_attributes)
      allow(service).to receive(:perform_additional_operations)
    end

    context 'when creating a new record' do
      let(:record) { double("Record", new_record?: true, save!: true) }

      before do
        allow(service).to receive(:find_or_initialize_record).and_return(record)
      end

      it 'saves the record and updates stats' do
        initial_stats = {
          processed: service.stats.processed,
          created: service.stats.created
        }

        service.send(:process_entity, entity_data)

        expect(record).to have_received(:save!)
        expect(service.stats.processed).to eq(initial_stats[:processed] + 1)
        expect(service.stats.created).to eq(initial_stats[:created] + 1)
      end

      it 'calls additional operations with created context' do
        service.send(:process_entity, entity_data)

        expect(service).to have_received(:perform_additional_operations)
          .with(record, enhanced_data, :created)
      end
    end

    context 'when updating an existing record' do
      let(:record) { double("Record", new_record?: false, changed?: true, save!: true) }

      before do
        allow(service).to receive(:find_or_initialize_record).and_return(record)
      end

      it 'saves the record and updates stats' do
        initial_stats = {
          processed: service.stats.processed,
          updated: service.stats.updated
        }

        service.send(:process_entity, entity_data)

        expect(record).to have_received(:save!)
        expect(service.stats.processed).to eq(initial_stats[:processed] + 1)
        expect(service.stats.updated).to eq(initial_stats[:updated] + 1)
      end
    end

    context 'when record is unchanged' do
      let(:record) { double("Record", new_record?: false, changed?: false) }

      before do
        allow(service).to receive(:find_or_initialize_record).and_return(record)
        allow(record).to receive(:save!)
      end

      it 'skips saving and updates stats' do
        initial_stats = {
          processed: service.stats.processed,
          skipped: service.stats.skipped
        }

        service.send(:process_entity, entity_data)

        expect(record).not_to have_received(:save!)
        expect(service.stats.processed).to eq(initial_stats[:processed] + 1)
        expect(service.stats.skipped).to eq(initial_stats[:skipped] + 1)
      end
    end

    context 'when save fails' do
      let(:record) { double("Record", new_record?: true) }
      let(:error) { ActiveRecord::RecordInvalid.new }

      before do
        allow(service).to receive(:find_or_initialize_record).and_return(record)
        allow(record).to receive(:save!).and_raise(error)
        allow(Rails.logger).to receive(:error)
        allow(Sentry).to receive(:capture_exception)
      end

      it 'handles error and updates failed stats' do
        expect {
          service.send(:process_batch, [ entity_data ], 1)
        }.not_to raise_error

        expect(service.stats.failed).to eq(1)
      end

      it 'logs error with context' do
        service.send(:process_batch, [ entity_data ], 1)

        expect(Rails.logger).to have_received(:error).with(
          hash_including(
            message: "Failed to process entity",
            entity_id: "123",
            error: error.message
          )
        )
      end

      it 'reports to Sentry' do
        service.send(:process_batch, [ entity_data ], 1)

        expect(Sentry).to have_received(:capture_exception).with(
          error,
          hash_including(
            extra: hash_including(
              entity_data: entity_data,
              entity_type: entity_type
            )
          )
        )
      end
    end
  end

  describe '#parse_file_content' do
    let(:entity_data) { { "uid" => "123", "file_url" => file_url } }
    let(:file_url) { "https://example.com/file.json" }
    let(:file_content) { { "test_entity" => { "detailed" => "data" } } }
    let(:response) { double("Response", success?: true, parsed_response: file_content) }

    context 'when file fetch succeeds' do
      before do
        allow(HTTParty).to receive(:get).with(file_url).and_return(response)
      end

      it 'enhances entity data with file details' do
        result = service.send(:parse_file_content, entity_data)

        expect(result).to include(entity_data)
        expect(result["file_details"]).to eq({ "detailed" => "data" })
      end
    end

    context 'when file fetch fails' do
      before do
        allow(HTTParty).to receive(:get).with(file_url).and_return(response)
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:code).and_return(404)
        allow(Rails.logger).to receive(:warn)
      end

      it 'returns original data unchanged' do
        result = service.send(:parse_file_content, entity_data)

        expect(result).to eq(entity_data)
        expect(result).not_to have_key("file_details")
      end

      it 'logs warning with status code' do
        service.send(:parse_file_content, entity_data)

        expect(Rails.logger).to have_received(:warn).with(
          hash_including(
            message: "Failed to fetch file content",
            status_code: 404
          )
        )
      end
    end

    context 'when no file_url provided' do
      let(:entity_data) { { "uid" => "123" } }

      before do
        allow(HTTParty).to receive(:get)
      end

      it 'returns data unchanged without HTTP request' do
        result = service.send(:parse_file_content, entity_data)

        expect(result).to eq(entity_data)
        expect(HTTParty).not_to have_received(:get)
      end
    end
  end

  describe '#import_all' do
    before do
      allow(SaumonNet::Entity).to receive(:list_all)
      allow(service).to receive(:process_batch)
    end

    it 'records successful import with final stats' do
      service.import_all

      expect(SaumonNet::HealthMonitoringService).to have_received(:record_successful_import)
        .with(entity_type, service.stats)
    end

    it 'logs completion with final statistics' do
      allow(Rails.logger).to receive(:info)

      service.import_all

      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          message: "Import completed",
          entity_type: entity_type,
          total_processed: service.stats.processed,
          success_rate: service.stats.success_rate
        )
      )
    end
  end

  describe 'ImportStats' do
    let(:stats) { SaumonNet::BaseImportService::ImportStats.new }

    describe '#success_rate' do
      it 'calculates correct success rate' do
        10.times { stats.increment_processed }
        2.times { stats.increment_failed }

        expect(stats.success_rate).to eq(80.0)
      end

      it 'handles zero processed entities' do
        expect(stats.success_rate).to eq(100.0)
      end

      it 'rounds to 2 decimal places' do
        3.times { stats.increment_processed }
        1.times { stats.increment_failed }

        expect(stats.success_rate).to eq(66.67)
      end
    end

    it 'tracks all operation types correctly' do
      stats.increment_processed
      stats.increment_created
      stats.increment_updated
      stats.increment_skipped
      stats.increment_failed

      expect(stats.processed).to eq(1)
      expect(stats.created).to eq(1)
      expect(stats.updated).to eq(1)
      expect(stats.skipped).to eq(1)
      expect(stats.failed).to eq(1)
    end
  end

  describe 'abstract method enforcement' do
    it 'requires subclasses to implement map_entity_attributes' do
      expect { service.send(:map_entity_attributes, {}) }
        .to raise_error(NotImplementedError, "Subclasses must implement map_entity_attributes")
    end

    it 'requires subclasses to implement find_or_initialize_record' do
      expect { service.send(:find_or_initialize_record, {}) }
        .to raise_error(NotImplementedError, "Subclasses must implement find_or_initialize_record")
    end
  end
end
