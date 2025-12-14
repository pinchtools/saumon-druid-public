require "rails_helper"

RSpec.describe Event::ErrorReporter do
  let(:event_id) { SecureRandom.uuid }
  let(:session_id) { SecureRandom.uuid }
  let(:category) { "import" }
  let(:action) { "failed" }
  let(:payload) { { "error" => "Something went wrong" } }
  let(:eventable_type) { nil }
  let(:eventable_id) { nil }
  let(:event) do
    build_stubbed(:event,
      id: event_id,
      category: category,
      action: action,
      severity: "error",
      payload: payload,
      session_id: session_id,
      eventable_type: eventable_type,
      eventable_id: eventable_id
    )
  end
  let(:reporter) { described_class.new(event) }
  let(:sentry_mock) do
    Module.new do
      def self.capture_message(*); end
    end
  end

  describe "#report" do
    before do
      stub_const("Sentry", sentry_mock)
      allow(Sentry).to receive(:capture_message)
    end

    it "sends message to Sentry with full_action and error" do
      reporter.report

      expect(Sentry).to have_received(:capture_message).with(
        "import.failed: Something went wrong",
        hash_including(level: :error)
      )
    end

    it "includes event metadata in extra" do
      reporter.report

      expect(Sentry).to have_received(:capture_message).with(
        anything,
        hash_including(extra: hash_including(event_id: event_id, session_id: session_id))
      )
    end

    it "includes category and action in tags" do
      reporter.report

      expect(Sentry).to have_received(:capture_message).with(
        anything,
        hash_including(tags: { event_category: "import", event_action: "failed" })
      )
    end

    context "when event has eventable" do
      let(:eventable_type) { "An::Stakeholder" }
      let(:eventable_id) { 42 }

      it "includes eventable identifier in extra" do
        reporter.report

        expect(Sentry).to have_received(:capture_message).with(
          anything,
          hash_including(extra: hash_including(eventable: "An::Stakeholder#42"))
        )
      end
    end

    context "when event has no eventable" do
      it "includes nil eventable in extra" do
        reporter.report

        expect(Sentry).to have_received(:capture_message).with(
          anything,
          hash_including(extra: hash_including(eventable: nil))
        )
      end
    end

    context "when payload has message instead of error" do
      let(:payload) { { "message" => "Custom message" } }

      it "uses message from payload" do
        reporter.report

        expect(Sentry).to have_received(:capture_message).with(
          /Custom message/,
          anything
        )
      end
    end

    context "when Sentry is not defined" do
      before { hide_const("Sentry") }

      it "does not raise an error" do
        expect { reporter.report }.not_to raise_error
      end
    end
  end
end
