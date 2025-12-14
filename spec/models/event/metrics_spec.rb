require "rails_helper"

RSpec.describe Event::Metrics do
  let(:event) { build_stubbed(:event, category: "import", action: "started", severity: "info") }
  let(:metrics) { described_class.new(event) }

  before do
    new_relic_agent = Module.new do
      def self.increment_metric(*); end
      def self.add_custom_attributes(*); end
      def self.record_metric(*); end
    end
    stub_const("NewRelic::Agent", new_relic_agent)
    allow(NewRelic::Agent).to receive(:increment_metric)
    allow(NewRelic::Agent).to receive(:add_custom_attributes)
    allow(NewRelic::Agent).to receive(:record_metric)
  end

  describe "#record" do
    it "increments the category/action metric" do
      metrics.record

      expect(NewRelic::Agent).to have_received(:increment_metric).with("Custom/Events/import/started")
    end

    it "increments the total events metric" do
      metrics.record

      expect(NewRelic::Agent).to have_received(:increment_metric).with("Custom/Events/Total")
    end

    it "adds custom attributes for the event" do
      metrics.record

      expect(NewRelic::Agent).to have_received(:add_custom_attributes).with(
        event_category: "import",
        event_action: "started",
        event_session_id: event.session_id,
        event_severity: "info"
      )
    end

    context "with error severity" do
      let(:event) { build_stubbed(:event, category: "import", severity: "error") }

      it "increments the error counter for the category" do
        metrics.record

        expect(NewRelic::Agent).to have_received(:increment_metric).with("Custom/Events/Errors/import")
      end
    end

    context "with non-error severity" do
      it "does not increment the error counter" do
        metrics.record

        expect(NewRelic::Agent).not_to have_received(:increment_metric).with(/Errors/)
      end
    end

    context "when NewRelic is not defined" do
      before { hide_const("NewRelic::Agent") }

      it { expect { metrics.record }.not_to raise_error }
    end
  end

  describe "action-specific metrics" do
    describe "import.completed" do
      let(:event) do
        build_stubbed(:event, :import_completed)
      end

      it "records import metrics for each stat" do
        metrics.record

        expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/SaumonNet/Import/stakeholders/Processed", event.payload["processed"])
        expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/SaumonNet/Import/stakeholders/Created", event.payload["created"])
        expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/SaumonNet/Import/stakeholders/Updated", event.payload["updated"])
        expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/SaumonNet/Import/stakeholders/Failed", event.payload["failed"])
      end

      context "without entity_type" do
        let(:event) do
          build_stubbed(:event, category: "import", action: "completed", payload: { "processed" => 100 })
        end

        it "uses 'unknown' as entity type" do
          metrics.record

          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Import/unknown/Processed", event.payload["processed"])
        end
      end
    end

    describe "import.entity_processed" do
      let(:event) do
        build_stubbed(:event, category: "import", action: "entity_processed", payload: { entity_type: "bodies" })
      end

      it "increments entity processed counter" do
        metrics.record

        expect(NewRelic::Agent).to have_received(:increment_metric).with("Custom/SaumonNet/Entity/bodies/Processed")
      end
    end

    describe "health.import_check" do
      context "with never_imported flag" do
        let(:event) do
          build_stubbed(:event,
            category: "health",
            action: "import_check",
            payload: {
              "entity_type" => "organe",
              "never_imported" => true
            })
        end

        it "records never imported metric" do
          metrics.record

          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Health/organe/NeverImported", 1)
        end
      end

      context "with age_hours and healthy status" do
        let(:event) do
          build_stubbed(:event,
            category: "health",
            action: "import_check",
            payload: {
              "entity_type" => "pays",
              "age_hours" => 12.5,
              "healthy" => true
            })
        end

        it "records age and health metrics" do
          metrics.record

          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Health/pays/AgeHours", event.payload["age_hours"])
          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Health/pays/Healthy", 1)
        end
      end

      context "with unhealthy status" do
        let(:event) do
          build_stubbed(:event,
            category: "health",
            action: "import_check",
            payload: {
              "entity_type" => "acteur",
              "healthy" => false
            })
        end

        it "records healthy as 0" do
          metrics.record

          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Health/acteur/Healthy", 0)
        end
      end

      context "with overall health status" do
        let(:event) do
          build_stubbed(:event,
            category: "health",
            action: "import_check",
            payload: {
              "overall_healthy" => true,
              "healthy_count" => 3,
              "total_count" => 4
            })
        end

        it "records overall health metrics" do
          metrics.record

          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Health/Overall/Healthy", 1)
          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Health/Overall/HealthyEntityCount", event.payload["healthy_count"])
          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Health/Overall/TotalEntityCount", event.payload["total_count"])
        end
      end
    end

    describe "health.api_check" do
      let(:event) do
        build_stubbed(:event,
          category: "health",
          action: "api_check",
          payload: {
            "response_time_ms" => 250.5,
            "healthy" => true
          })
      end

      it "records API health metrics" do
        metrics.record

        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/API/ResponseTime", event.payload["response_time_ms"])
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/API/Healthy", 1)
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/API/ConnectivityCheck", 1)
      end

      context "without response_time_ms" do
        let(:event) do
          build_stubbed(:event,
            category: "health",
            action: "api_check",
            payload: { "healthy" => true })
        end

        it "records healthy and connectivity check metrics" do
          metrics.record

          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/API/Healthy", 1)
          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/API/ConnectivityCheck", 1)
        end
      end
    end

    describe "health.api_check_failed" do
      let(:event) do
        build_stubbed(:event,
          category: "health",
          action: "api_check_failed",
          severity: "error",
          payload: { "error" => "Connection timeout" })
      end

      it "records API failure metrics" do
        metrics.record

        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/API/Healthy", 0)
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/API/Errors", 1)
      end
    end

    describe "health.queue_check" do
      let(:event) do
        build_stubbed(:event,
          category: "health",
          action: "queue_check",
          payload: {
            "healthy" => true,
            "total_enqueued" => 55,
            "failed_count" => 10,
            "retry_count" => 5,
            "processed_today" => 1000,
            "failed_today" => 3,
            "queue_sizes" => { "default" => 50, "critical" => 5 },
            "alerts" => nil
          })
      end

      it "records queue health metrics" do
        metrics.record

        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Sidekiq/Healthy", 1)
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Sidekiq/TotalEnqueued", event.payload["total_enqueued"])
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Sidekiq/FailedCount", event.payload["failed_count"])
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Sidekiq/RetryCount", event.payload["retry_count"])
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Sidekiq/ProcessedToday", event.payload["processed_today"])
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Sidekiq/FailedToday", event.payload["failed_today"])
      end

      it "records individual queue sizes" do
        metrics.record

        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Sidekiq/Queue/default/Size", event.payload["queue_sizes"]["default"])
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Sidekiq/Queue/critical/Size", event.payload["queue_sizes"]["critical"])
      end

      context "with alerts" do
        let(:event) do
          build_stubbed(:event,
            category: "health",
            action: "queue_check",
            payload: {
              "healthy" => false,
              "total_enqueued" => 1500,
              "alerts" => [ "QueueSizeExceeded", "LargeQueuesDetected" ]
            })
        end

        it "records alert metrics" do
          metrics.record

          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Sidekiq/Alerts/QueueSizeExceeded", 1)
          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Sidekiq/Alerts/LargeQueuesDetected", 1)
        end
      end

      context "with missing values" do
        let(:event) do
          build_stubbed(:event,
            category: "health",
            action: "queue_check",
            payload: { "healthy" => true })
        end

        it "uses defaults of 0 for missing values" do
          metrics.record

          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Sidekiq/TotalEnqueued", 0)
          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Sidekiq/FailedCount", 0)
        end
      end
    end

    describe "health.queue_check_failed" do
      let(:event) do
        build_stubbed(:event,
          category: "health",
          action: "queue_check_failed",
          severity: "error",
          payload: { "error" => "Sidekiq unavailable" })
      end

      it "records queue failure metric" do
        metrics.record

        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Sidekiq/Healthy", 0)
      end
    end

    describe "health.full_check" do
      let(:timestamp) { Time.current.iso8601 }
      let(:event) do
        build_stubbed(:event,
          category: "health",
          action: "full_check",
          payload: {
            "healthy" => true,
            "timestamp" => timestamp,
            "imports_healthy" => true,
            "api_healthy" => true,
            "queues_healthy" => true,
            "failed_check_count" => 0
          })
      end

      it "records full health check metrics" do
        metrics.record

        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Health/FullCheck/Overall", 1)
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Health/FullCheck/ImportsHealthy", 1)
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Health/FullCheck/APIHealthy", 1)
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Health/FullCheck/QueuesHealthy", 1)
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/SaumonNet/Health/FullCheck/FailedCheckCount", 0)
      end

      it "adds custom attributes for health check" do
        metrics.record

        expect(NewRelic::Agent).to have_received(:add_custom_attributes).with(
          hash_including(
            "saumon_net.health_check.timestamp" => timestamp,
            "saumon_net.health.overall" => true,
            "saumon_net.health.imports" => true,
            "saumon_net.health.api" => true,
            "saumon_net.health.queues" => true
          )
        )
      end

      context "with failed checks" do
        let(:event) do
          build_stubbed(:event,
            category: "health",
            action: "full_check",
            payload: {
              "healthy" => false,
              "imports_healthy" => false,
              "api_healthy" => true,
              "queues_healthy" => false,
              "failed_check_count" => 2
            })
        end

        it "records unhealthy status correctly" do
          metrics.record

          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Health/FullCheck/Overall", 0)
          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Health/FullCheck/ImportsHealthy", 0)
          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Health/FullCheck/APIHealthy", 1)
          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Health/FullCheck/QueuesHealthy", 0)
          expect(NewRelic::Agent).to have_received(:record_metric)
            .with("Custom/SaumonNet/Health/FullCheck/FailedCheckCount", event.payload["failed_check_count"])
        end
      end
    end
  end
end
