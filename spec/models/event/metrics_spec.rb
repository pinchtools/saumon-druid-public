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

    context "with import.completed action" do
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
    end

    context "with import.entity_processed action" do
      let(:event) do
        build_stubbed(:event, category: "import", action: "entity_processed", payload: { entity_type: "bodies" })
      end

      it "increments entity processed counter" do
        metrics.record

        expect(NewRelic::Agent).to have_received(:increment_metric).with("Custom/SaumonNet/Entity/bodies/Processed")
      end
    end

    context "with health.check_performed action" do
      let(:event) do
        build_stubbed(:event, category: "health", action: "check_performed", payload: { response_time: 150 })
      end

      it "records response time metric" do
        metrics.record

        expect(NewRelic::Agent).to have_received(:record_metric).
          with("Custom/SaumonNet/Health/ResponseTime", event.payload["response_time"])
      end
    end

    context "when NewRelic is not defined" do
      before { hide_const("NewRelic::Agent") }

      it { expect { metrics.record }.not_to raise_error }
    end
  end
end
