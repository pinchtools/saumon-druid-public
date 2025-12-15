require "rails_helper"

RSpec.describe Event::ErrorReporterJob, type: :job do
  include ActiveJob::TestHelper

  let(:event) { create(:event, :error) }
  let(:error_reporter) { instance_double(Event::ErrorReporter, report: nil) }

  before do
    allow(Event::ErrorReporter).to receive(:new).and_return(error_reporter)
  end

  describe "#perform" do
    it "reports the error for the event" do
      described_class.new.perform(event.id)

      expect(Event::ErrorReporter).to have_received(:new).with(event)
      expect(error_reporter).to have_received(:report)
    end

    context "when event is not found" do
      it "discards the job without raising" do
        expect {
          perform_enqueued_jobs do
            described_class.perform_later(-1)
          end
        }.not_to raise_error
      end
    end
  end

  describe "job configuration" do
    it "is queued on default queue" do
      expect(described_class.queue_name).to eq("monitoring")
    end
  end
end
