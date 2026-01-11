# frozen_string_literal: true

require "rails_helper"

RSpec.describe Conversation::Response::Orchestrator do
  let(:conversation) { create(:conversation) }
  let(:user_message) { conversation.add_user_message("What is the answer?") }
  let(:assistant_message) { conversation.add_assistant_message }

  subject(:service) { described_class.new(conversation: conversation, message: assistant_message) }

  before do
    user_message
  end

  describe "constants" do
    it "defines event constants" do
      expect(described_class::EVENT_STARTED).to eq("started")
      expect(described_class::EVENT_COMPLETED).to eq("completed")
      expect(described_class::EVENT_HALTED).to eq("halted")
      expect(described_class::EVENT_ERROR).to eq("error")
    end
  end

  describe "#execute" do
    let(:query_planner_result) { { plan: "v1", confidence: 0.9 } }
    let(:query_executor_result) { { results: { data: "test data" } } }
    let(:answer_composer_result) { { answer: "The answer is 42" } }

    let(:mock_query_planner) { instance_double("Agent::QueryPlannerV2") }
    let(:mock_answer_composer) { instance_double("Agent::AnswerComposer") }
    let(:mock_query_executor) { instance_double(QueryExecutorService) }

    before do
      allow(Agent).to receive_message_chain(:with_name, :active, :exists?).and_return(false)

      stub_const("Agent::QueryPlannerV2", Class.new)
      stub_const("Agent::AnswerComposer", Class.new)

      allow(Agent::QueryPlannerV2).to receive(:new).and_return(mock_query_planner)
      allow(mock_query_planner).to receive(:call).and_return(query_planner_result)

      allow(QueryExecutorService).to receive(:new).and_return(mock_query_executor)
      allow(mock_query_executor).to receive(:execute).and_return(query_executor_result)

      allow(Agent::AnswerComposer).to receive(:new).and_return(mock_answer_composer)
      allow(mock_answer_composer).to receive(:call).and_return(answer_composer_result)
    end

    it "marks the message as processing" do
      service.execute
      expect(assistant_message.reload.status).not_to eq(Message::STATUS_PENDING)
    end

    it "runs the pipeline stages" do
      expect(mock_query_planner).to receive(:call)
      expect(mock_query_executor).to receive(:execute)
      expect(mock_answer_composer).to receive(:call)

      service.execute
    end

    it "completes the message with the answer" do
      service.execute

      assistant_message.reload
      expect(assistant_message.content).to eq("The answer is 42")
      expect(assistant_message.status).to eq(Message::STATUS_COMPLETED)
    end

    it "completes the conversation" do
      service.execute
      expect(conversation.reload.status).to eq(Conversation::STATUS_COMPLETED)
    end

    it "returns a success response" do
      result = service.execute

      expect(result[:success]).to be true
      expect(result[:message_id]).to eq(assistant_message.id)
      expect(result[:content]).to eq("The answer is 42")
      expect(result[:duration_ms]).to be_a(Integer)
    end

    context "when no user message exists" do
      before do
        conversation.messages.by_role(Message::ROLE_USER).destroy_all
      end

      it "fails with an error" do
        result = service.execute

        expect(result[:success]).to be false
        expect(result[:error]).to include("No user message found")
      end
    end

    context "when answer composer returns empty answer" do
      let(:answer_composer_result) { { answer: nil } }

      it "fails the message" do
        service.execute

        assistant_message.reload
        expect(assistant_message.status).to eq(Message::STATUS_FAILED)
        expect(assistant_message.content).to include("Unable to generate response")
      end
    end

    context "when a stage halts the pipeline" do
      let(:query_planner_result) { { halt: true, halt_reason: "Query is unsafe" } }

      it "halts execution and fails the message" do
        service.execute

        assistant_message.reload
        expect(assistant_message.status).to eq(Message::STATUS_FAILED)
      end

      it "returns halted response" do
        result = service.execute

        expect(result[:success]).to be false
        expect(result[:error]).to include("Query is unsafe")
      end
    end

    context "when a stage raises an error with on_fail: :halt" do
      before do
        allow(mock_query_planner).to receive(:call).and_raise(StandardError.new("Agent crashed"))
      end

      it "fails the message" do
        service.execute

        assistant_message.reload
        expect(assistant_message.status).to eq(Message::STATUS_FAILED)
        expect(assistant_message.content).to include("Agent crashed")
      end

      it "fails the conversation" do
        service.execute
        expect(conversation.reload.status).to eq(Conversation::STATUS_FAILED)
      end

      it "returns an error response" do
        result = service.execute

        expect(result[:success]).to be false
        expect(result[:error]).to include("Agent crashed")
      end
    end

    context "when skip_remaining is signaled" do
      let(:query_planner_result) { { skip_remaining: true, skip_reason: "Cached answer found" } }

      it "skips remaining stages" do
        expect(mock_query_executor).not_to receive(:execute)
        expect(mock_answer_composer).not_to receive(:call)

        service.execute
      end
    end

    context "when optional stages are skipped" do
      it "skips optional agent stages that are not configured" do
        result = service.execute
        expect(result[:success]).to be true
      end
    end
  end

  describe "event tracking" do
    let(:mock_query_planner) { instance_double("Agent::QueryPlannerV2") }
    let(:mock_answer_composer) { instance_double("Agent::AnswerComposer") }
    let(:mock_query_executor) { instance_double(QueryExecutorService) }

    before do
      allow(Agent).to receive_message_chain(:with_name, :active, :exists?).and_return(false)

      stub_const("Agent::QueryPlannerV2", Class.new)
      stub_const("Agent::AnswerComposer", Class.new)

      allow(Agent::QueryPlannerV2).to receive(:new).and_return(mock_query_planner)
      allow(mock_query_planner).to receive(:call).and_return({ plan: "v1" })

      allow(QueryExecutorService).to receive(:new).and_return(mock_query_executor)
      allow(mock_query_executor).to receive(:execute).and_return({ results: {} })

      allow(Agent::AnswerComposer).to receive(:new).and_return(mock_answer_composer)
      allow(mock_answer_composer).to receive(:call).and_return({ answer: "Test" })
    end

    it "tracks started event" do
      expect(service).to receive(:track_event).with("started", anything).and_call_original
      allow(service).to receive(:track_event).and_call_original

      service.execute
    end

    it "tracks completed event on success" do
      allow(service).to receive(:track_event).and_call_original
      expect(service).to receive(:track_event).with("completed", anything).and_call_original

      service.execute
    end

    it "includes stages_executed in completed event" do
      service.execute

      completed_event = Event.where(category: "orchestrator", action: "completed").last
      expect(completed_event.payload["stages_executed"]).to include("query_planner", "query_executor", "answer_composer")
    end
  end
end
