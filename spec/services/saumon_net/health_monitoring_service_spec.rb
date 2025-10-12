require 'rails_helper'
require "sidekiq/api"

RSpec.describe SaumonNet::HealthMonitoringService do
  let(:entity_type) { "organe" }
  let(:stats) { double("Stats", processed: 100, created: 20, updated: 30, skipped: 40, failed: 10, success_rate: 90.0) }

  before do
    allow(SaumonNet).to receive(:configure)
    allow(Rails.cache).to receive_messages(write: true, read: nil)
    allow(Rails.logger).to receive_messages(error: nil)
  end

  describe '.record_successful_import' do
    it 'caches import status with timestamp and stats' do
      freeze_time do
        described_class.record_successful_import(entity_type, stats)

        expected_data = {
          timestamp: Time.current.iso8601,
          stats: {
            processed: 100,
            created: 20,
            updated: 30,
            skipped: 40,
            failed: 10,
            success_rate: 90.0
          }
        }

        expect(Rails.cache).to have_received(:write).with(
          "saumon_net:import_status:#{entity_type}",
          expected_data,
          expires_in: 30.days
        )
      end
    end

    it 'handles nil stats gracefully' do
      freeze_time do
        described_class.record_successful_import(entity_type, nil)

        expected_data = {
          timestamp: Time.current.iso8601,
          stats: nil
        }

        expect(Rails.cache).to have_received(:write).with(
          "saumon_net:import_status:#{entity_type}",
          expected_data,
          expires_in: 30.days
        )
      end
    end

    context 'with New Relic available' do
      before do
        stub_const("NewRelic::Agent", double("Agent"))
        allow(NewRelic::Agent).to receive_messages(
          record_metric: nil,
          add_custom_attributes: nil
        )
      end

      it 'records metrics to New Relic' do
        freeze_time do
          described_class.record_successful_import(entity_type, stats)

          expect(NewRelic::Agent).to have_received(:record_metric).with(
            "Custom/SaumonNet/Import/#{entity_type}/LastSuccess",
            Time.current.to_i
          )

          expect(NewRelic::Agent).to have_received(:record_metric).with(
            "Custom/SaumonNet/Import/#{entity_type}/LastSuccessRate",
            90.0
          )

          expect(NewRelic::Agent).to have_received(:add_custom_attributes).with(
            hash_including(
              "saumon_net.import.entity_type" => entity_type,
              "saumon_net.import.processed" => 100,
              "saumon_net.import.success_rate" => 90.0
            )
          )
        end
      end
    end
  end

  describe '.last_import_status' do
    it 'reads from cache using correct key' do
      described_class.last_import_status(entity_type)

      expect(Rails.cache).to have_received(:read).with(
        "saumon_net:import_status:#{entity_type}"
      )
    end
  end

  describe '.import_health_status' do
    let(:recent_import) do
      {
        timestamp: 2.hours.ago.iso8601,
        stats: { processed: 100, success_rate: 95.0 }
      }
    end

    let(:stale_import) do
      {
        timestamp: 25.hours.ago.iso8601,
        stats: { processed: 50, success_rate: 80.0 }
      }
    end

    before do
      allow(described_class).to receive(:last_import_status).with("organe").and_return(recent_import)
      allow(described_class).to receive(:last_import_status).with("pays").and_return(recent_import)
      allow(described_class).to receive(:last_import_status).with("acteur").and_return(recent_import)
    end

    it 'reports healthy status for recent imports' do
      result = described_class.import_health_status

      expect(result[:overall_healthy]).to be true
      expect(result[:entity_types]["organe"][:healthy]).to be true
      expect(result[:entity_types]["organe"][:status]).to eq("healthy")
      expect(result[:entity_types]["organe"][:age_hours]).to be_within(0.1).of(2.0)
    end

    context 'with stale import' do
      before do
        allow(described_class).to receive(:last_import_status).with("organe").and_return(stale_import)
        allow(described_class).to receive(:last_import_status).with("pays").and_return(stale_import)
        allow(described_class).to receive(:last_import_status).with("acteur").and_return(stale_import)
      end

      it 'reports unhealthy status for stale imports' do
        result = described_class.import_health_status

        expect(result[:overall_healthy]).to be false
        expect(result[:entity_types]["organe"][:healthy]).to be false
        expect(result[:entity_types]["organe"][:status]).to eq("stale")
        expect(result[:entity_types]["organe"][:age_hours]).to be_within(0.1).of(25.0)
      end
    end

    context 'with no import history' do
      before do
        allow(described_class).to receive(:last_import_status).with("organe").and_return(nil)
        allow(described_class).to receive(:last_import_status).with("pays").and_return(nil)
        allow(described_class).to receive(:last_import_status).with("acteur").and_return(nil)
      end

      it 'reports never imported status' do
        result = described_class.import_health_status

        expect(result[:overall_healthy]).to be false
        expect(result[:entity_types]["organe"][:status]).to eq("never_imported")
        expect(result[:entity_types]["organe"][:healthy]).to be false
      end
    end
  end

  describe '.api_health_check' do
    before do
      allow(SaumonNet::Entity).to receive(:list_all)
      # Mock the benchmark method since it requires a logger
      allow(described_class).to receive(:benchmark).and_yield
    end

    context 'when API responds successfully' do
      before do
        allow(SaumonNet::Entity).to receive(:list_all).and_yield([ { "uid" => "123" } ])
      end

      it 'reports healthy API status' do
        result = described_class.api_health_check
        expect(result[:healthy]).to be true
        expect(result[:status]).to eq("connected")
        expect(result[:response_time_ms]).to be_a(Numeric)
        expect(result[:entity_count]).to eq(1)
      end
    end

    context 'when API fails' do
      let(:api_error) { StandardError.new("Connection timeout") }

      before do
        allow(SaumonNet::Entity).to receive(:list_all).and_raise(api_error)
      end

      it 'reports unhealthy API status' do
        result = described_class.api_health_check

        expect(result[:healthy]).to be false
        expect(result[:status]).to eq("error")
        expect(result[:error]).to eq("Connection timeout")
        expect(result[:error_type]).to eq("StandardError")
      end

      it 'logs error with context' do
        described_class.api_health_check

        expect(Rails.logger).to have_received(:error)
      end
    end
  end

  describe '.queue_health_check' do
    let(:sidekiq_stats) { double("Stats", processed: 1000, failed: 5, retry_size: 10) }
    let(:default_queue) { double("Queue", name: "default", size: 50) }
    let(:critical_queue) { double("Queue", name: "critical", size: 5) }
    let(:retry_set) { double("RetrySet", size: 10) }

    before do
      allow(Sidekiq::Stats).to receive(:new).and_return(sidekiq_stats)
      allow(Sidekiq::Queue).to receive(:all).and_return([ default_queue, critical_queue ])
      allow(Sidekiq::RetrySet).to receive(:new).and_return(retry_set)
    end

    context 'with healthy queue status' do
      it 'reports healthy queue status' do
        result = described_class.queue_health_check
        expect(result[:healthy]).to be true
        expect(result[:total_enqueued]).to eq(55)
        expect(result[:failed_count]).to eq(10)
        expect(result[:retry_count]).to eq(10)
        expect(result[:queue_sizes]).to eq({
          "default" => 50,
          "critical" => 5
        })
        expect(result[:large_queues]).to be_empty
      end
    end

    context 'with unhealthy queue status' do
      let(:large_queue) { double("Queue", name: "large", size: 1500) }

      before do
        allow(Sidekiq::Queue).to receive(:all).and_return([ default_queue, large_queue ])
        allow(retry_set).to receive(:size).and_return(60)
      end

      it 'reports unhealthy status for large queues' do
        result = described_class.queue_health_check

        expect(result[:healthy]).to be false
        expect(result[:large_queues]).to eq([ "large" ])
        expect(result[:total_enqueued]).to eq(1550)
      end
    end

    context 'when Sidekiq check fails' do
      let(:sidekiq_error) { StandardError.new("Sidekiq unavailable") }

      before do
        allow(Sidekiq::Stats).to receive(:new).and_raise(sidekiq_error)
        allow(Rails.logger).to receive(:error)
      end

      it 'reports error status' do
        result = described_class.queue_health_check

        expect(result[:healthy]).to be false
        expect(result[:error]).to eq("Sidekiq unavailable")
        expect(result[:error_type]).to eq("StandardError")
      end
    end
  end

  describe '.full_health_check' do
    let(:import_status) { { overall_healthy: true } }
    let(:api_status) { { healthy: true } }
    let(:queue_status) { { healthy: true } }

    before do
      allow(described_class).to receive_messages(
        import_health_status: import_status,
        api_health_check: api_status,
        queue_health_check: queue_status
      )
    end

    context 'when all checks pass' do
      it 'reports overall healthy status' do
        result = described_class.full_health_check

        expect(result[:healthy]).to be true
        expect(result[:checks][:imports]).to eq(import_status)
        expect(result[:checks][:api]).to eq(api_status)
        expect(result[:checks][:queues]).to eq(queue_status)
        expect(result[:timestamp]).to be_present
      end
    end

    context 'when any check fails' do
      let(:api_status) { { healthy: false } }

      it 'reports overall unhealthy status' do
        result = described_class.full_health_check

        expect(result[:healthy]).to be false
      end
    end

    context 'with New Relic available' do
      before do
        stub_const("NewRelic::Agent", double("Agent"))
        allow(NewRelic::Agent).to receive_messages(
          record_metric: nil,
          add_custom_attributes: nil
        )
      end

      it 'records comprehensive metrics' do
        described_class.full_health_check

        expect(NewRelic::Agent).to have_received(:record_metric).with(
          "Custom/SaumonNet/Health/FullCheck/Overall", 1
        )

        expect(NewRelic::Agent).to have_received(:add_custom_attributes).with(
          hash_including(
            "saumon_net.health.overall" => true,
            "saumon_net.health.imports" => true,
            "saumon_net.health.api" => true,
            "saumon_net.health.queues" => true
          )
        )
      end
    end
  end

  def freeze_time(&block)
    travel_to(Time.current, &block)
  end
end
