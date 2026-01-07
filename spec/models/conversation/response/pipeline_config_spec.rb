# frozen_string_literal: true

require "rails_helper"

RSpec.describe Conversation::Response::PipelineConfig do
  describe "Stage" do
    let(:stage) do
      described_class::Stage.new(
        name: "query_planner",
        agent_class: "Agent::QueryPlannerV2",
        service_class: nil,
        optional: false,
        on_fail: :halt,
        conditions: nil
      )
    end

    describe "#agent?" do
      it "returns true when agent_class is present" do
        expect(stage.agent?).to be true
      end

      it "returns false when agent_class is nil" do
        service_stage = described_class::Stage.new(
          name: "query_executor",
          agent_class: nil,
          service_class: "QueryExecutorService",
          optional: false,
          on_fail: :halt,
          conditions: nil
        )
        expect(service_stage.agent?).to be false
      end
    end

    describe "#service?" do
      it "returns true when service_class is present" do
        service_stage = described_class::Stage.new(
          name: "query_executor",
          agent_class: nil,
          service_class: "QueryExecutorService",
          optional: false,
          on_fail: :halt,
          conditions: nil
        )
        expect(service_stage.service?).to be true
      end

      it "returns false when service_class is nil" do
        expect(stage.service?).to be false
      end
    end
  end

  describe "PIPELINE" do
    it "is frozen" do
      expect(described_class::PIPELINE).to be_frozen
    end

    it "contains expected stages" do
      stage_names = described_class::PIPELINE.map(&:name)
      expect(stage_names).to include("safety_check", "query_rewriter", "query_planner", "query_executor", "answer_composer")
    end

    it "has safety_check as first stage" do
      expect(described_class::PIPELINE.first.name).to eq("safety_check")
    end

    it "has answer_composer as last stage" do
      expect(described_class::PIPELINE.last.name).to eq("answer_composer")
    end

    describe "stage configurations" do
      it "marks safety_check as optional" do
        stage = described_class.find_stage("safety_check")
        expect(stage.optional).to be true
        expect(stage.on_fail).to eq(:halt)
      end

      it "marks query_rewriter as optional with continue on_fail" do
        stage = described_class.find_stage("query_rewriter")
        expect(stage.optional).to be true
        expect(stage.on_fail).to eq(:continue)
      end

      it "marks query_planner as required" do
        stage = described_class.find_stage("query_planner")
        expect(stage.optional).to be false
        expect(stage.on_fail).to eq(:halt)
      end

      it "marks query_executor as service stage with condition" do
        stage = described_class.find_stage("query_executor")
        expect(stage.service?).to be true
        expect(stage.conditions).to be_present
      end

      it "marks answer_composer as agent stage with condition" do
        stage = described_class.find_stage("answer_composer")
        expect(stage.agent?).to be true
        expect(stage.conditions).to be_present
      end
    end
  end

  describe ".stages" do
    it "returns the PIPELINE" do
      expect(described_class.stages).to eq(described_class::PIPELINE)
    end
  end

  describe ".find_stage" do
    it "finds a stage by name" do
      stage = described_class.find_stage("query_planner")
      expect(stage).to be_present
      expect(stage.name).to eq("query_planner")
    end

    it "accepts symbol names" do
      stage = described_class.find_stage(:query_planner)
      expect(stage).to be_present
    end

    it "returns nil for unknown stage" do
      expect(described_class.find_stage("unknown")).to be_nil
    end
  end

  describe ".agent_stages" do
    it "returns only stages with agent_class" do
      stages = described_class.agent_stages
      expect(stages).to all(be_agent)
      expect(stages.map(&:name)).to include("safety_check", "query_rewriter", "query_planner", "answer_composer")
    end

    it "excludes service stages" do
      stages = described_class.agent_stages
      expect(stages.map(&:name)).not_to include("query_executor")
    end
  end

  describe ".service_stages" do
    it "returns only stages with service_class" do
      stages = described_class.service_stages
      expect(stages).to all(be_service)
      expect(stages.map(&:name)).to include("query_executor")
    end

    it "excludes agent stages" do
      stages = described_class.service_stages
      expect(stages.map(&:name)).not_to include("query_planner")
    end
  end
end
