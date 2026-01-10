# frozen_string_literal: true

require "rails_helper"

RSpec.describe Conversation::Response::ProcessingJob, type: :job do
  include ActiveJob::TestHelper

  let(:conversation) { create(:conversation) }
  let(:message) { create(:message, :assistant, :pending, conversation: conversation) }
  let(:orchestrator) { instance_double(Conversation::Response::Orchestrator) }

  before do
    allow(Conversation::Response::Orchestrator).to receive(:new).and_return(orchestrator)
  end

  describe "#perform" do
    context "when successful" do
      let(:result) { { success: true, duration_ms: 150 } }

      before do
        allow(orchestrator).to receive(:execute).and_return(result)
      end

      it "executes the orchestrator" do
        described_class.new.perform(conversation.id, message.id)

        expect(Conversation::Response::Orchestrator).to have_received(:new).with(
          conversation: conversation,
          message: message
        )
        expect(orchestrator).to have_received(:execute)
      end

      it "tracks job_completed event" do
        expect {
          described_class.new.perform(conversation.id, message.id)
        }.to change(Event, :count).by(1)

        event = Event.where(action: "job_completed").last
        expect(event.payload["conversation_id"]).to eq(conversation.id)
        expect(event.payload["message_id"]).to eq(message.id)
        expect(event.payload["duration_ms"]).to eq(150)
      end
    end

    context "when orchestrator returns failure" do
      let(:result) { { success: false, error: "LLM unavailable" } }

      before do
        allow(orchestrator).to receive(:execute).and_return(result)
      end

      it "tracks job_failed event" do
        expect {
          described_class.new.perform(conversation.id, message.id)
        }.to change(Event, :count).by(1)

        event = Event.where(action: "job_failed").last
        expect(event.severity).to eq("error")
        expect(event.payload["error"]).to eq("LLM unavailable")
      end
    end

    context "when message is already processed" do
      let(:message) { create(:message, :assistant, :completed, conversation: conversation) }

      it "skips processing" do
        described_class.new.perform(conversation.id, message.id)

        expect(Conversation::Response::Orchestrator).not_to have_received(:new)
      end

      it "tracks job_skipped event" do
        expect {
          described_class.new.perform(conversation.id, message.id)
        }.to change(Event, :count).by(1)

        event = Event.where(action: "job_skipped").last
        expect(event.payload["reason"]).to eq("already_processed")
        expect(event.payload["current_status"]).to eq("completed")
      end
    end

    context "when conversation is not found" do
      it "tracks job_error event and does not raise" do
        expect {
          described_class.new.perform(-1, message.id)
        }.to change(Event, :count).by(1)

        event = Event.where(action: "job_error").last
        expect(event.severity).to eq("error")
        expect(event.payload["error_class"]).to eq("ActiveRecord::RecordNotFound")
      end
    end

    context "when message is not found" do
      it "tracks job_error event and does not raise" do
        expect {
          described_class.new.perform(conversation.id, -1)
        }.to change(Event, :count).by(1)

        event = Event.where(action: "job_error").last
        expect(event.payload["error_class"]).to eq("ActiveRecord::RecordNotFound")
      end
    end

    context "when orchestrator raises an error" do
      before do
        allow(orchestrator).to receive(:execute).and_raise(StandardError, "Something went wrong")
      end

      it "tracks job_error event and re-raises" do
        expect {
          described_class.new.perform(conversation.id, message.id)
        }.to raise_error(StandardError, "Something went wrong")
          .and change(Event, :count).by(1)

        event = Event.where(action: "job_error").last
        expect(event.payload["error_class"]).to eq("StandardError")
        expect(event.payload["error_message"]).to eq("Something went wrong")
        expect(event.payload["backtrace"]).to be_present
      end
    end

    it "sets Current attributes" do
      allow(orchestrator).to receive(:execute).and_return({ success: true, duration_ms: 100 })

      described_class.new.perform(conversation.id, message.id)

      expect(Current.conversation_id).to eq(conversation.id)
      expect(Current.message_id).to eq(message.id)
    end
  end

  describe "job configuration" do
    it "is queued on default queue" do
      expect(described_class.queue_name).to eq("default")
    end
  end
end
