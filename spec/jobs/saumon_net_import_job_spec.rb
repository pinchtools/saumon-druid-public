require 'rails_helper'

RSpec.describe SaumonNetImportJob, type: :job do
  describe '#perform' do
    let(:entity_type) { 'organe' }
    let(:since_date) { nil }
    let(:import_service) { instance_double(SaumonNet::BodyImportService) }
    let(:stats) { double('stats', processed: 10, created: 5, updated: 3, skipped: 1, failed: 1, success_rate: 0.9) }

    before do
      allow(SaumonNet::BodyImportService).to receive(:new).and_return(import_service)
      allow(import_service).to receive(:import_all).and_return(stats)
      allow(import_service).to receive(:import_since).and_return(stats)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow(NewRelic::Agent).to receive(:record_metric) if defined?(NewRelic::Agent)
    end

    context 'with organe entity type' do
      it 'builds BodyImportService and calls import_all when no since_date' do
        expect(SaumonNet::BodyImportService).to receive(:new)
        expect(import_service).to receive(:import_all)

        described_class.new.perform(entity_type)
      end

      it 'calls import_since when since_date is provided' do
        since_date = '2023-01-01'
        parsed_date = DateTime.parse(since_date)

        expect(import_service).to receive(:import_since).with(parsed_date)

        described_class.new.perform(entity_type, since_date)
      end
    end

    context 'with pays entity type' do
      let(:entity_type) { 'pays' }
      let(:import_service) { instance_double(SaumonNet::CountryImportService) }

      before do
        allow(SaumonNet::CountryImportService).to receive(:new).and_return(import_service)
        allow(import_service).to receive(:import_all).and_return(stats)
      end

      it 'builds CountryImportService' do
        expect(SaumonNet::CountryImportService).to receive(:new)

        described_class.new.perform(entity_type)
      end
    end

    context 'with unknown entity type' do
      let(:entity_type) { 'unknown' }

      it 'raises ArgumentError' do
        expect {
          described_class.new.perform(entity_type)
        }.to raise_error(ArgumentError, "Unknown entity type: unknown")
      end
    end

    context 'logging' do
      it 'logs successful completion with stats' do
        expected_stats = {
          processed: 10,
          created: 5,
          updated: 3,
          skipped: 1,
          failed: 1,
          success_rate: 0.9
        }

        expect(Rails.logger).to receive(:info).with(
          message: "Import job completed",
          component: SaumonNet::COMPONENT,
          entity_type: entity_type,
          since_date: since_date,
          stats: expected_stats
        )

        described_class.new.perform(entity_type, since_date)
      end

      it 'logs errors and re-raises them' do
        error = StandardError.new("Import failed")
        allow(import_service).to receive(:import_all).and_raise(error)

        expect(Rails.logger).to receive(:error).with(
          message: "Import job failed",
          component: SaumonNet::COMPONENT,
          entity_type: entity_type,
          since_date: since_date,
          error: "Import failed",
          backtrace: error.backtrace
        )

        expect {
          described_class.new.perform(entity_type, since_date)
        }.to raise_error(StandardError, "Import failed")
      end
    end

    context 'metrics tracking' do
      context 'when NewRelic is available' do
        before do
          stub_const('NewRelic::Agent', Class.new)
          allow(NewRelic::Agent).to receive(:record_metric)
        end

        it 'records metrics for the import' do
          expect(NewRelic::Agent).to receive(:record_metric).with("Custom/SaumonNet/Import/#{entity_type}/Processed", 10)
          expect(NewRelic::Agent).to receive(:record_metric).with("Custom/SaumonNet/Import/#{entity_type}/Created", 5)
          expect(NewRelic::Agent).to receive(:record_metric).with("Custom/SaumonNet/Import/#{entity_type}/Updated", 3)
          expect(NewRelic::Agent).to receive(:record_metric).with("Custom/SaumonNet/Import/#{entity_type}/Failed", 1)
          expect(NewRelic::Agent).to receive(:record_metric).with("Custom/SaumonNet/Import/#{entity_type}/SuccessRate", 0.9)

          described_class.new.perform(entity_type)
        end
      end

      context 'when NewRelic is not available' do
        before do
          hide_const('NewRelic::Agent') if defined?(NewRelic::Agent)
        end

        it 'does not attempt to record metrics' do
          expect { described_class.new.perform(entity_type) }.not_to raise_error
        end
      end
    end
  end

  describe '#build_import_service' do
    let(:job) { described_class.new }

    it 'returns BodyImportService for organe entity type' do
      service = job.send(:build_import_service, 'organe')
      expect(service).to be_an_instance_of(SaumonNet::BodyImportService)
    end

    it 'returns CountryImportService for pays entity type' do
      service = job.send(:build_import_service, 'pays')
      expect(service).to be_an_instance_of(SaumonNet::CountryImportService)
    end

    it 'raises ArgumentError for unknown entity type' do
      expect {
        job.send(:build_import_service, 'unknown')
      }.to raise_error(ArgumentError, "Unknown entity type: unknown")
    end
  end

  describe '#parse_since_date' do
    let(:job) { described_class.new }

    context 'with string date' do
      it 'parses valid date string' do
        result = job.send(:parse_since_date, '2023-01-01')
        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(1)
        expect(result.day).to eq(1)
      end

      it 'parses ISO 8601 date string' do
        result = job.send(:parse_since_date, '2023-01-01T10:30:00Z')
        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.hour).to eq(10)
        expect(result.min).to eq(30)
      end

      it 'raises ArgumentError for invalid date string' do
        expect {
          job.send(:parse_since_date, 'invalid-date')
        }.to raise_error(ArgumentError, /Invalid since_date format/)
      end
    end

    context 'with invalid type' do
      it 'raises ArgumentError for integer' do
        expect {
          job.send(:parse_since_date, 123)
        }.to raise_error(ArgumentError, "Invalid since_date format: 123")
      end

      it 'raises ArgumentError for nil' do
        expect {
          job.send(:parse_since_date, nil)
        }.to raise_error(ArgumentError, "Invalid since_date format: ")
      end
    end
  end

  describe '#stats_summary' do
    let(:job) { described_class.new }
    let(:stats) { double('stats', processed: 10, created: 5, updated: 3, skipped: 1, failed: 1, success_rate: 0.9) }

    it 'returns a hash with all stats' do
      result = job.send(:stats_summary, stats)

      expect(result).to eq({
        processed: 10,
        created: 5,
        updated: 3,
        skipped: 1,
        failed: 1,
        success_rate: 0.9
      })
    end
  end

  describe 'error handling' do
    it 'discards on SaumonNet::AuthenticationError' do
      expect(described_class.discard_on).to include(SaumonNet::AuthenticationError)
    end

    it 'discards on SaumonNet::ConfigurationError' do
      expect(described_class.discard_on).to include(SaumonNet::ConfigurationError)
    end

    it 'is queued on default queue' do
      expect(described_class.queue_name).to eq('default')
    end
  end
end
