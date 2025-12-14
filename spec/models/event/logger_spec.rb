require "rails_helper"

RSpec.describe Event::Logger do
  let(:event) { build_stubbed(:event, category: "import", action: "started", severity: "info", payload: { count: 10 }) }
  let(:logger) { described_class.new(event) }

  describe "#log" do
    before { allow(Rails.logger).to receive(:info) }

    it "logs with the correct severity level" do
      logger.log

      expect(Rails.logger).to have_received(:info)
    end

    it "includes full_action in the message" do
      logger.log

      expect(Rails.logger).to have_received(:info).with(hash_including(event: "import.started"))
    end

    it "includes event metadata in the message" do
      logger.log

      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          severity: "info",
          session_id: event.session_id,
          request_id: event.request_id,
          job_id: event.job_id
        )
      )
    end

    it "includes payload data in the message" do
      logger.log

      expect(Rails.logger).to have_received(:info).with(hash_including(count: 10))
    end

    context "with debug severity" do
      let(:event) { build_stubbed(:event, severity: "debug") }

      before { allow(Rails.logger).to receive(:debug) }

      it "logs at debug level" do
        logger.log

        expect(Rails.logger).to have_received(:debug)
      end
    end

    context "with warn severity" do
      let(:event) { build_stubbed(:event, severity: "warn") }

      before { allow(Rails.logger).to receive(:warn) }

      it "logs at warn level" do
        logger.log

        expect(Rails.logger).to have_received(:warn)
      end
    end

    context "with error severity" do
      let(:event) { build_stubbed(:event, severity: "error") }

      before { allow(Rails.logger).to receive(:error) }

      it "logs at error level" do
        logger.log

        expect(Rails.logger).to have_received(:error)
      end
    end

    context "with eventable" do
      let(:event) { build_stubbed(:event, eventable_type: "An::Body", eventable_id: 123) }

      it "includes eventable identifier" do
        logger.log

        expect(Rails.logger).to have_received(:info).with(hash_including(eventable: "An::Body#123"))
      end
    end

    context "without eventable" do
      let(:event) { build_stubbed(:event, eventable_type: nil) }

      it "includes nil eventable" do
        logger.log

        expect(Rails.logger).to have_received(:info).with(hash_including(eventable: nil))
      end
    end
  end
end
