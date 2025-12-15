require "rails_helper"

RSpec.describe Event::Observer do
  include ActiveJob::TestHelper

  let(:event) { create(:event) }
  let(:observer) { described_class.new(event) }
  let(:logger) { instance_double(Event::Logger, log: nil) }

  before do
    allow(Event::Logger).to receive(:new).with(event).and_return(logger)
  end

  describe "#observe" do
    it "logs the event synchronously" do
      observer.observe

      expect(logger).to have_received(:log)
    end

    it "enqueues the metrics job" do
      expect {
        observer.observe
      }.to have_enqueued_job(Event::MetricsJob).with(event.id)
    end

    context "with error severity" do
      let(:event) { create(:event, :error) }

      it "enqueues the error reporter job" do
        expect {
          observer.observe
        }.to have_enqueued_job(Event::ErrorReporterJob).with(event.id)
      end
    end

    context "with non-error severity" do
      let(:event) { create(:event, severity: "info") }

      it "does not enqueue the error reporter job" do
        expect {
          observer.observe
        }.not_to have_enqueued_job(Event::ErrorReporterJob)
      end
    end
  end
end
