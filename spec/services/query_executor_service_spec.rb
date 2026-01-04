# frozen_string_literal: true

require "rails_helper"

RSpec.describe QueryExecutorService do
  describe "#execute" do
    context "with valid single-step plan" do
      let(:query_plan) do
        {
          "confidence" => 5,
          "steps" => [
            {
              "id" => "find_president",
              "target_model" => "stakeholder",
              "action" => "search",
              "parameters" => [ "president" ],
              "quantifier" => "one"
            }
          ]
        }
      end

      before do
        allow(An::Stakeholder).to receive(:all).and_return(An::Stakeholder.none)
        allow(An::Stakeholder.none).to receive_messages(
          lexical_search: An::Stakeholder.none,
          to_a: []
        )
      end

      it "returns a success result" do
        service = described_class.new(question: "Who is the president?", query_plan: query_plan)
        result = service.execute

        expect(result[:success]).to be true
        expect(result[:question]).to eq("Who is the president?")
        expect(result[:confidence]).to eq(5)
        expect(result[:results]).to have_key("find_president")
      end
    end

    context "with multi-step plan with dependencies" do
      let(:query_plan) do
        {
          "confidence" => 4,
          "steps" => [
            {
              "id" => "step_a",
              "target_model" => "stakeholder",
              "action" => "search",
              "parameters" => [ "test" ]
            },
            {
              "id" => "step_b",
              "target_model" => "stakeholder",
              "action" => "search",
              "parameters" => [ "test2" ]
            },
            {
              "id" => "step_c",
              "target_model" => "terms",
              "action" => nil,
              "depends_on" => [ "step_a", "step_b" ]
            }
          ]
        }
      end

      before do
        allow(An::Stakeholder).to receive(:all).and_return(An::Stakeholder.none)
        allow(An::Stakeholder.none).to receive_messages(
          search: An::Stakeholder.none,
          to_a: []
        )

        allow(An::Term).to receive(:all).and_return(An::Term.none)
        allow(An::Term.none).to receive(:to_a).and_return([])
      end

      it "executes steps in correct order based on dependencies" do
        service = described_class.new(question: "Test question", query_plan: query_plan)
        result = service.execute

        expect(result[:success]).to be true
        expect(result[:results].keys).to contain_exactly("step_a", "step_b", "step_c")
      end
    end

    context "with parallel independent steps" do
      let(:query_plan) do
        {
          "confidence" => 5,
          "steps" => [
            {
              "id" => "parallel_1",
              "target_model" => "stakeholder",
              "action" => "search",
              "parameters" => [ "query1" ]
            },
            {
              "id" => "parallel_2",
              "target_model" => "stakeholder",
              "action" => "search",
              "parameters" => [ "query2" ]
            },
            {
              "id" => "parallel_3",
              "target_model" => "stakeholder",
              "action" => "search",
              "parameters" => [ "query3" ]
            }
          ]
        }
      end

      before do
        allow(An::Stakeholder).to receive(:all).and_return(An::Stakeholder.none)
        allow(An::Stakeholder.none).to receive_messages(
          lexical_search: An::Stakeholder.none,
          to_a: []
        )
      end

      it "executes all steps" do
        service = described_class.new(question: "Test", query_plan: query_plan)
        result = service.execute

        expect(result[:success]).to be true
        expect(result[:step_count]).to eq(3)
      end
    end

    context "with invalid query plan" do
      it "raises error for plan without steps" do
        service = described_class.new(
          question: "Test",
          query_plan: { "confidence" => 5 }
        )

        expect { service.execute }.to raise_error(QueryExecutorService::ExecutionError)
      end

      it "raises error for empty steps array" do
        service = described_class.new(
          question: "Test",
          query_plan: { "steps" => [] }
        )

        expect { service.execute }.to raise_error(QueryExecutorService::ExecutionError)
      end
    end

    context "with cyclic dependencies" do
      let(:query_plan) do
        {
          "steps" => [
            {
              "id" => "step_a",
              "target_model" => "stakeholder",
              "depends_on" => [ "step_b" ]
            },
            {
              "id" => "step_b",
              "target_model" => "stakeholder",
              "depends_on" => [ "step_a" ]
            }
          ]
        }
      end

      it "returns error result for cyclic dependencies" do
        service = described_class.new(question: "Test", query_plan: query_plan)
        result = service.execute

        expect(result[:success]).to be false
        expect(result[:answer]).to include("Cyclic dependency")
      end
    end

    context "with step failure" do
      let(:query_plan) do
        {
          "steps" => [
            {
              "id" => "failing_step",
              "target_model" => "unknown_model"
            },
            {
              "id" => "dependent_step",
              "target_model" => "stakeholder",
              "depends_on" => [ "failing_step" ]
            }
          ]
        }
      end

      it "fails fast and returns failure result" do
        service = described_class.new(question: "Test", query_plan: query_plan)
        result = service.execute

        expect(result[:success]).to be false
        expect(result[:failed_steps]).to include("failing_step")
      end
    end
  end

  describe "#build_execution_levels" do
    it "groups independent steps together" do
      steps = [
        { "id" => "a", "depends_on" => nil },
        { "id" => "b", "depends_on" => nil },
        { "id" => "c", "depends_on" => [ "a", "b" ] }
      ]

      service = described_class.new(
        question: "Test",
        query_plan: { "steps" => steps }
      )

      levels = service.send(:build_execution_levels)

      expect(levels.length).to eq(2)
      expect(levels[0].map { |s| s["id"] }).to contain_exactly("a", "b")
      expect(levels[1].map { |s| s["id"] }).to eq([ "c" ])
    end

    it "handles complex dependency chains" do
      steps = [
        { "id" => "a", "depends_on" => nil },
        { "id" => "b", "depends_on" => [ "a" ] },
        { "id" => "c", "depends_on" => [ "a" ] },
        { "id" => "d", "depends_on" => [ "b", "c" ] }
      ]

      service = described_class.new(
        question: "Test",
        query_plan: { "steps" => steps }
      )

      levels = service.send(:build_execution_levels)

      expect(levels.length).to eq(3)
      expect(levels[0].map { |s| s["id"] }).to eq([ "a" ])
      expect(levels[1].map { |s| s["id"] }).to contain_exactly("b", "c")
      expect(levels[2].map { |s| s["id"] }).to eq([ "d" ])
    end
  end

  describe "event tracking" do
    let(:query_plan) do
      {
        "confidence" => 5,
        "steps" => [
          {
            "id" => "test_step",
            "target_model" => "stakeholder",
            "action" => "search",
            "parameters" => [ "test" ]
          }
        ]
      }
    end

    before do
      allow(An::Stakeholder).to receive(:all).and_return(An::Stakeholder.none)
      allow(An::Stakeholder.none).to receive_messages(
        lexical_search: An::Stakeholder.none,
        to_a: []
      )
    end

    def query_executor_events(action)
      Event.where(category: "query_executor", action: action)
    end

    describe "on successful execution" do
      it "creates a started event" do
        service = described_class.new(question: "Test question", query_plan: query_plan)

        expect { service.execute }.to change { query_executor_events("started").count }.by(1)
      end

      it "creates a completed event" do
        service = described_class.new(question: "Test question", query_plan: query_plan)

        expect { service.execute }.to change { query_executor_events("completed").count }.by(1)
      end

      it "tracks started event with correct payload" do
        service = described_class.new(question: "Test question", query_plan: query_plan)
        service.execute

        event = query_executor_events("started").last
        expect(event.category).to eq("query_executor")
        expect(event.severity).to eq("info")
        expect(event.payload["question"]).to eq("Test question")
        expect(event.payload["step_count"]).to eq(1)
        expect(event.payload["confidence"]).to eq(5)
      end

      it "tracks completed event with correct payload" do
        service = described_class.new(question: "Test question", query_plan: query_plan)
        service.execute

        event = query_executor_events("completed").last
        expect(event.category).to eq("query_executor")
        expect(event.severity).to eq("info")
        expect(event.payload["duration_ms"]).to be_a(Integer)
        expect(event.payload["step_count"]).to eq(1)
        expect(event.payload["success_count"]).to eq(1)
        expect(event.payload["failed_count"]).to eq(0)
      end
    end

    describe "on step failure" do
      let(:failing_plan) do
        {
          "steps" => [
            {
              "id" => "failing_step",
              "target_model" => "unknown_model"
            }
          ]
        }
      end

      it "creates started and completed events even when steps fail" do
        service = described_class.new(question: "Test", query_plan: failing_plan)

        expect { service.execute }.to change { query_executor_events("started").count }.by(1)
          .and change { query_executor_events("completed").count }.by(1)
      end

      it "tracks failed step count in completed event" do
        service = described_class.new(question: "Test", query_plan: failing_plan)
        service.execute

        event = query_executor_events("completed").last
        expect(event.payload["failed_count"]).to eq(1)
      end
    end

    describe "on cyclic dependency error" do
      let(:cyclic_plan) do
        {
          "steps" => [
            { "id" => "a", "target_model" => "stakeholder", "depends_on" => [ "b" ] },
            { "id" => "b", "target_model" => "stakeholder", "depends_on" => [ "a" ] }
          ]
        }
      end

      it "creates an error event" do
        service = described_class.new(question: "Test", query_plan: cyclic_plan)

        expect { service.execute }.to change { query_executor_events("error").count }.by(1)
      end

      it "tracks error event with error details" do
        service = described_class.new(question: "Test", query_plan: cyclic_plan)
        service.execute

        event = query_executor_events("error").last
        expect(event.severity).to eq("error")
        expect(event.payload["error_class"]).to eq("QueryExecution::DependencyGraph::CyclicDependencyError")
        expect(event.payload["error_message"]).to include("Cyclic dependency")
      end
    end

    describe "on timeout" do
      before do
        allow_any_instance_of(described_class).to receive(:wait_for_futures).and_raise(Concurrent::TimeoutError)
      end

      let(:parallel_plan) do
        {
          "steps" => [
            { "id" => "a", "target_model" => "stakeholder" },
            { "id" => "b", "target_model" => "stakeholder" }
          ]
        }
      end

      it "creates a timeout event" do
        service = described_class.new(question: "Test", query_plan: parallel_plan)

        expect { service.execute }.to change { query_executor_events("timeout").count }.by(1)
      end

      it "tracks timeout event with duration and limit" do
        service = described_class.new(question: "Test", query_plan: parallel_plan)
        service.execute

        event = query_executor_events("timeout").last
        expect(event.severity).to eq("error")
        expect(event.payload["timeout_limit"]).to eq(QueryExecutorService::EXECUTION_TIMEOUT)
        expect(event.payload["duration_ms"]).to be_a(Integer)
      end
    end
  end
end
