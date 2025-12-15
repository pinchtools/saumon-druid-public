require "rails_helper"

RSpec.describe Event::MetricsJob, type: :job do
  include ActiveJob::TestHelper

  let(:event) { create(:event) }
  let(:metrics) { instance_double(Event::Metrics, record: nil) }

  before do
    allow(Event::Metrics).to receive(:new).and_return(metrics)
  end

  describe "#perform" do
    it "records metrics for the event" do
      described_class.new.perform(event.id)

      expect(Event::Metrics).to have_received(:new).with(event)
      expect(metrics).to have_received(:record)
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
      expect(described_class.queue_name).to eq("default")
    end
  end
end
