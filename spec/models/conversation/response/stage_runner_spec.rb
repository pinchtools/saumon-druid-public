# frozen_string_literal: true

require "rails_helper"

RSpec.describe Conversation::Response::StageRunner do
  let(:conversation) { create(:conversation) }
  let(:message) { create(:message, conversation: conversation) }
  let(:question) { "What is the answer?" }
  let(:context) do
    Conversation::Response::Context.new(
      conversation: conversation,
      message: message,
      question: question
    )
  end

  let(:stage) do
    Conversation::Response::PipelineConfig::Stage.new(
      name: "query_planner",
      agent_class: "Agent::QueryPlannerV2",
      service_class: nil,
      optional: false,
      on_fail: :halt,
      conditions: nil
    )
  end

  subject(:runner) { described_class.new(stage: stage, context: context) }

  describe "#initialize" do
    it "sets stage and context" do
      expect(runner.stage).to eq(stage)
      expect(runner.context).to eq(context)
    end

    it "generates an execution_id" do
      expect(runner.execution_id).to be_present
    end

    it "accepts a custom execution_id" do
      runner = described_class.new(stage: stage, context: context, execution_id: "custom-123")
      expect(runner.execution_id).to eq("custom-123")
    end
  end

  describe "#attempt_number" do
    it "returns 1 for first attempt" do
      expect(runner.attempt_number).to eq(1)
    end

    it "increments with each stored result" do
      context.store_result("query_planner", { plan: "v1" })
      expect(runner.attempt_number).to eq(2)

      context.store_result("query_planner", { plan: "v2" })
      expect(runner.attempt_number).to eq(3)
    end
  end

  describe "#run" do
    context "when stage is an optional agent that is not configured" do
      let(:stage) do
        Conversation::Response::PipelineConfig::Stage.new(
          name: "safety_check",
          agent_class: "Agent::SafetyAgent",
          service_class: nil,
          optional: true,
          on_fail: :halt,
          conditions: nil
        )
      end

      before do
        allow(Agent).to receive_message_chain(:with_name, :active, :exists?).and_return(false)
      end

      it "returns a skipped result" do
        result = runner.run

        expect(result).to be_a(Conversation::Response::StageResult)
        expect(result.skipped?).to be true
        expect(result.skip_reason).to eq(:agent_not_configured)
      end
    end

    context "when stage condition is not met" do
      let(:stage) do
        Conversation::Response::PipelineConfig::Stage.new(
          name: "query_executor",
          agent_class: nil,
          service_class: "QueryExecutorService",
          optional: false,
          on_fail: :halt,
          conditions: ->(ctx) { ctx.get_result("query_planner").present? }
        )
      end

      it "returns a skipped result" do
        result = runner.run

        expect(result).to be_a(Conversation::Response::StageResult)
        expect(result.skipped?).to be true
        expect(result.skip_reason).to eq(:condition_not_met)
      end
    end

    context "when executing an agent stage" do
      let(:agent_result) { { plan: "query_plan_v1", confidence: 0.9 } }
      let(:mock_agent) { instance_double("Agent::QueryPlannerV2") }

      before do
        stub_const("Agent::QueryPlannerV2", Class.new)
        allow(Agent::QueryPlannerV2).to receive(:new).and_return(mock_agent)
        allow(mock_agent).to receive(:call).and_return(agent_result)
      end

      it "executes the agent and returns success" do
        result = runner.run

        expect(result).to be_a(Conversation::Response::StageResult)
        expect(result.success?).to be true
        expect(result.data).to eq(agent_result)
      end

      it "stores the result in context" do
        runner.run
        expect(context.get_result("query_planner")).to eq(agent_result)
      end

      it "stores execution_id with the result" do
        runner.run
        execution = context.get_executions("query_planner").last
        expect(execution.id).to eq(runner.execution_id)
      end
    end

    context "when executing a service stage" do
      let(:stage) do
        Conversation::Response::PipelineConfig::Stage.new(
          name: "query_executor",
          agent_class: nil,
          service_class: "QueryExecutorService",
          optional: false,
          on_fail: :halt,
          conditions: nil
        )
      end

      let(:service_result) { { results: { data: "test" } } }
      let(:mock_service) { instance_double(QueryExecutorService) }

      before do
        context.store_result("query_planner", { plan: "v1" })
        allow(QueryExecutorService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:execute).and_return(service_result)
      end

      it "executes the service and returns success" do
        result = runner.run

        expect(result).to be_a(Conversation::Response::StageResult)
        expect(result.success?).to be true
        expect(result.data).to eq(service_result)
      end
    end

    context "when agent returns halt signal" do
      let(:agent_result) { { halt: true, halt_reason: "Unsafe content detected" } }
      let(:mock_agent) { instance_double("Agent::QueryPlannerV2") }

      before do
        stub_const("Agent::QueryPlannerV2", Class.new)
        allow(Agent::QueryPlannerV2).to receive(:new).and_return(mock_agent)
        allow(mock_agent).to receive(:call).and_return(agent_result)
      end

      it "halts the context" do
        runner.run
        expect(context.halted?).to be true
        expect(context.get_metadata("halt_reason")).to eq("Unsafe content detected")
      end
    end

    context "when agent returns skip_remaining signal" do
      let(:agent_result) { { skip_remaining: true, skip_reason: "Answer found in cache" } }
      let(:mock_agent) { instance_double("Agent::QueryPlannerV2") }

      before do
        stub_const("Agent::QueryPlannerV2", Class.new)
        allow(Agent::QueryPlannerV2).to receive(:new).and_return(mock_agent)
        allow(mock_agent).to receive(:call).and_return(agent_result)
      end

      it "sets skip_remaining on context" do
        runner.run
        expect(context.skip_remaining?).to be true
        expect(context.get_metadata("skip_reason")).to eq("Answer found in cache")
      end
    end

    context "when stage raises an error" do
      let(:error) { StandardError.new("Agent failed") }
      let(:mock_agent) { instance_double("Agent::QueryPlannerV2") }

      before do
        stub_const("Agent::QueryPlannerV2", Class.new)
        allow(Agent::QueryPlannerV2).to receive(:new).and_return(mock_agent)
        allow(mock_agent).to receive(:call).and_raise(error)
      end

      context "with on_fail: :halt" do
        it "returns a failed result with halted flag" do
          result = runner.run

          expect(result.failed?).to be true
          expect(result.halted?).to be true
          expect(result.error).to eq(error)
        end

        it "halts the context" do
          runner.run
          expect(context.halted?).to be true
          expect(context.get_metadata("halt_reason")).to eq("Agent failed")
        end
      end

      context "with on_fail: :continue" do
        let(:stage) do
          Conversation::Response::PipelineConfig::Stage.new(
            name: "query_rewriter",
            agent_class: "Agent::QueryPlannerV2",
            service_class: nil,
            optional: true,
            on_fail: :continue,
            conditions: nil
          )
        end

        before do
          # Make the agent lookup return true so the optional stage isn't skipped
          allow(Agent).to receive_message_chain(:with_name, :active, :exists?).and_return(true)
        end

        it "returns a failed result without halted flag" do
          result = runner.run

          expect(result.failed?).to be true
          expect(result.halted?).to be false
        end

        it "stores error in metadata but does not halt" do
          runner.run
          expect(context.halted?).to be false
          expect(context.get_metadata("query_rewriter_error")).to eq("Agent failed")
        end
      end
    end

    context "when stage has invalid configuration" do
      let(:stage) do
        Conversation::Response::PipelineConfig::Stage.new(
          name: "invalid",
          agent_class: nil,
          service_class: nil,
          optional: false,
          on_fail: :raise,
          conditions: nil
        )
      end

      it "raises ArgumentError" do
        expect { runner.run }.to raise_error(ArgumentError, /Invalid stage configuration/)
      end
    end

    context "when service is unknown" do
      let(:stage) do
        Conversation::Response::PipelineConfig::Stage.new(
          name: "unknown_service",
          agent_class: nil,
          service_class: "UnknownService",
          optional: false,
          on_fail: :raise,
          conditions: nil
        )
      end

      it "raises ArgumentError" do
        expect { runner.run }.to raise_error(ArgumentError, /Unknown service/)
      end
    end
  end
end
