require "rails_helper"

RSpec.describe Event::Observer do
  let(:event) { build_stubbed(:event) }
  let(:observer) { described_class.new(event) }
  let(:logger) { instance_double(Event::Logger, log: nil) }
  let(:metrics) { instance_double(Event::Metrics, record: nil) }
  let(:error_reporter) { instance_double(Event::ErrorReporter, report: nil) }

  before do
    allow(Event::Logger).to receive(:new).with(event).and_return(logger)
    allow(Event::Metrics).to receive(:new).with(event).and_return(metrics)
    allow(Event::ErrorReporter).to receive(:new).with(event).and_return(error_reporter)
  end

  describe "#observe" do
    it "logs the event" do
      observer.observe

      expect(logger).to have_received(:log)
    end

    it "records metrics" do
      observer.observe

      expect(metrics).to have_received(:record)
    end

    context "with error severity" do
      let(:event) { build_stubbed(:event, :error) }

      it "reports the error" do
        observer.observe

        expect(error_reporter).to have_received(:report)
      end
    end

    context "with non-error severity" do
      let(:event) { build_stubbed(:event, severity: "info") }

      it "does not report an error" do
        observer.observe

        expect(error_reporter).not_to have_received(:report)
      end
    end
  end
end
