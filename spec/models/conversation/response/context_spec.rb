# frozen_string_literal: true

require "rails_helper"

RSpec.describe Conversation::Response::Context do
  let(:conversation) { build(:conversation) }
  let(:message) { build(:message, conversation: conversation) }
  let(:question) { "What is the answer?" }

  subject(:context) do
    described_class.new(conversation: conversation, message: message, question: question)
  end

  describe "#initialize" do
    it "sets conversation, message and question" do
      expect(context.conversation).to eq(conversation)
      expect(context.message).to eq(message)
      expect(context.question).to eq(question)
    end

    it "initializes with empty results" do
      expect(context.results).to eq({})
    end

    it "initializes with halted as false" do
      expect(context.halted?).to be false
    end

    it "initializes with skip_remaining as false" do
      expect(context.skip_remaining?).to be false
    end
  end

  describe "result storage" do
    describe "#store_result" do
      it "stores a result for a stage" do
        entry = context.store_result("query_planner", { plan: "v1" })

        expect(entry).to be_a(Conversation::Response::Context::ExecutionEntry)
        expect(entry.result).to eq({ plan: "v1" })
        expect(entry.at).to be_present
      end

      it "generates execution_id if not provided" do
        entry = context.store_result("query_planner", { plan: "v1" })
        expect(entry.id).to be_present
      end

      it "uses provided execution_id" do
        entry = context.store_result("query_planner", { plan: "v1" }, execution_id: "custom-id")
        expect(entry.id).to eq("custom-id")
      end

      it "allows multiple results for the same stage" do
        context.store_result("query_planner", { plan: "v1" }, execution_id: "exec-1")
        context.store_result("query_planner", { plan: "v2" }, execution_id: "exec-2")

        expect(context.execution_count("query_planner")).to eq(2)
      end
    end

    describe "#get_result" do
      it "returns nil when no result exists" do
        expect(context.get_result("query_planner")).to be_nil
      end

      it "returns the most recent result" do
        context.store_result("query_planner", { plan: "v1" })
        context.store_result("query_planner", { plan: "v2" })

        expect(context.get_result("query_planner")).to eq({ plan: "v2" })
      end
    end

    describe "#get_executions" do
      it "returns all executions for a stage" do
        context.store_result("query_planner", { plan: "v1" }, execution_id: "exec-1")
        context.store_result("query_planner", { plan: "v2" }, execution_id: "exec-2")

        executions = context.get_executions("query_planner")
        expect(executions.map(&:id)).to eq(%w[exec-1 exec-2])
      end

      it "returns empty array when no executions exist" do
        expect(context.get_executions("query_planner")).to eq([])
      end
    end

    describe "#get_execution" do
      before do
        context.store_result("query_planner", { plan: "v1" }, execution_id: "exec-1")
        context.store_result("query_planner", { plan: "v2" }, execution_id: "exec-2")
      end

      it "returns a specific execution by id" do
        execution = context.get_execution("query_planner", "exec-1")
        expect(execution.result).to eq({ plan: "v1" })
      end

      it "returns nil when execution not found" do
        expect(context.get_execution("query_planner", "nonexistent")).to be_nil
      end
    end

    describe "#execution_count" do
      it "returns 0 when no executions exist" do
        expect(context.execution_count("query_planner")).to eq(0)
      end

      it "returns the number of executions" do
        context.store_result("query_planner", { plan: "v1" })
        context.store_result("query_planner", { plan: "v2" })

        expect(context.execution_count("query_planner")).to eq(2)
      end
    end

    describe "#results" do
      it "returns latest results for all stages" do
        context.store_result("query_planner", { plan: "v1" })
        context.store_result("query_planner", { plan: "v2" })
        context.store_result("query_executor", { data: "results" })

        expect(context.results).to eq({
          "query_planner" => { plan: "v2" },
          "query_executor" => { data: "results" }
        })
      end
    end

    describe "#all_results" do
      it "returns full history for all stages" do
        context.store_result("query_planner", { plan: "v1" }, execution_id: "exec-1")
        context.store_result("query_planner", { plan: "v2" }, execution_id: "exec-2")

        all_results = context.all_results
        expect(all_results["query_planner"].size).to eq(2)
      end
    end
  end

  describe "metadata" do
    describe "#set_metadata and #get_metadata" do
      it "stores and retrieves metadata" do
        context.set_metadata("key", "value")
        expect(context.get_metadata("key")).to eq("value")
      end

      it "converts keys to strings" do
        context.set_metadata(:symbol_key, "value")
        expect(context.get_metadata("symbol_key")).to eq("value")
      end
    end

    describe "#metadata" do
      it "returns all metadata as hash" do
        context.set_metadata("key1", "value1")
        context.set_metadata("key2", "value2")

        expect(context.metadata).to eq({ "key1" => "value1", "key2" => "value2" })
      end
    end
  end

  describe "flow control" do
    describe "#halt!" do
      it "sets halted to true" do
        context.halt!
        expect(context.halted?).to be true
      end

      it "stores halt reason in metadata" do
        context.halt!(reason: "Safety check failed")
        expect(context.get_metadata("halt_reason")).to eq("Safety check failed")
      end
    end

    describe "#skip_remaining!" do
      it "sets skip_remaining to true" do
        context.skip_remaining!
        expect(context.skip_remaining?).to be true
      end

      it "stores skip reason in metadata" do
        context.skip_remaining!(reason: "Answer already found")
        expect(context.get_metadata("skip_reason")).to eq("Answer already found")
      end
    end
  end

  describe "#session_id" do
    it "returns the conversation session_id" do
      allow(conversation).to receive(:session_id).and_return("test-session-id")
      expect(context.session_id).to eq("test-session-id")
    end
  end

  describe "#to_h" do
    let(:conversation) { create(:conversation) }
    let(:message) { create(:message, conversation: conversation) }

    subject(:context) do
      described_class.new(conversation: conversation, message: message, question: question)
    end

    before do
      context.store_result("query_planner", { plan: "v1" })
      context.set_metadata("key", "value")
    end

    it "returns a hash representation" do
      hash = context.to_h

      expect(hash[:conversation_id]).to eq(conversation.id)
      expect(hash[:message_id]).to eq(message.id)
      expect(hash[:question]).to eq(question)
      expect(hash[:results]).to eq({ "query_planner" => { plan: "v1" } })
      expect(hash[:metadata]).to eq({ "key" => "value" })
      expect(hash[:halted]).to be false
      expect(hash[:skip_remaining]).to be false
    end
  end
end
