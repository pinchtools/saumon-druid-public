# frozen_string_literal: true

require "rails_helper"

RSpec.describe Conversation::Response::StageResult do
  describe "constants" do
    it "defines status constants" do
      expect(described_class::STATUS_SUCCESS).to eq(:success)
      expect(described_class::STATUS_FAILED).to eq(:failed)
      expect(described_class::STATUS_SKIPPED).to eq(:skipped)
    end
  end

  describe "#initialize" do
    it "creates an immutable result" do
      result = described_class.new(stage_name: "test", status: :success)
      expect(result).to be_frozen
    end

    it "stores all attributes" do
      result = described_class.new(
        stage_name: "query_planner",
        status: :success,
        data: { plan: "v1" },
        error: nil,
        skip_reason: nil,
        execution_id: "exec-123",
        halted: false
      )

      expect(result.stage_name).to eq("query_planner")
      expect(result.status).to eq(:success)
      expect(result.data).to eq({ plan: "v1" })
      expect(result.execution_id).to eq("exec-123")
    end
  end

  describe "status predicates" do
    describe "#success?" do
      it "returns true when status is success" do
        result = described_class.new(stage_name: "test", status: described_class::STATUS_SUCCESS)
        expect(result.success?).to be true
      end

      it "returns false when status is not success" do
        result = described_class.new(stage_name: "test", status: described_class::STATUS_FAILED)
        expect(result.success?).to be false
      end
    end

    describe "#failed?" do
      it "returns true when status is failed" do
        result = described_class.new(stage_name: "test", status: described_class::STATUS_FAILED)
        expect(result.failed?).to be true
      end

      it "returns false when status is not failed" do
        result = described_class.new(stage_name: "test", status: described_class::STATUS_SUCCESS)
        expect(result.failed?).to be false
      end
    end

    describe "#skipped?" do
      it "returns true when status is skipped" do
        result = described_class.new(stage_name: "test", status: described_class::STATUS_SKIPPED)
        expect(result.skipped?).to be true
      end

      it "returns false when status is not skipped" do
        result = described_class.new(stage_name: "test", status: described_class::STATUS_SUCCESS)
        expect(result.skipped?).to be false
      end
    end

    describe "#halted?" do
      it "returns true when halted flag is set" do
        result = described_class.new(stage_name: "test", status: :failed, halted: true)
        expect(result.halted?).to be true
      end

      it "returns false when halted flag is not set" do
        result = described_class.new(stage_name: "test", status: :failed, halted: false)
        expect(result.halted?).to be false
      end

      it "defaults to false" do
        result = described_class.new(stage_name: "test", status: :failed)
        expect(result.halted?).to be false
      end
    end
  end

  describe "factory methods" do
    describe ".success" do
      it "creates a success result" do
        result = described_class.success("query_planner", { plan: "v1" })

        expect(result.stage_name).to eq("query_planner")
        expect(result.status).to eq(described_class::STATUS_SUCCESS)
        expect(result.data).to eq({ plan: "v1" })
        expect(result.success?).to be true
      end

      it "accepts an execution_id" do
        result = described_class.success("query_planner", { plan: "v1" }, execution_id: "exec-123")
        expect(result.execution_id).to eq("exec-123")
      end
    end

    describe ".failed" do
      let(:error) { StandardError.new("Something went wrong") }

      it "creates a failed result" do
        result = described_class.failed("query_planner", error)

        expect(result.stage_name).to eq("query_planner")
        expect(result.status).to eq(described_class::STATUS_FAILED)
        expect(result.error).to eq(error)
        expect(result.failed?).to be true
      end

      it "accepts an execution_id" do
        result = described_class.failed("query_planner", error, execution_id: "exec-123")
        expect(result.execution_id).to eq("exec-123")
      end

      it "accepts a halted flag" do
        result = described_class.failed("query_planner", error, halted: true)
        expect(result.halted?).to be true
      end

      it "defaults halted to false" do
        result = described_class.failed("query_planner", error)
        expect(result.halted?).to be false
      end
    end

    describe ".skipped" do
      it "creates a skipped result" do
        result = described_class.skipped("safety_check", :agent_not_configured)

        expect(result.stage_name).to eq("safety_check")
        expect(result.status).to eq(described_class::STATUS_SKIPPED)
        expect(result.skip_reason).to eq(:agent_not_configured)
        expect(result.skipped?).to be true
      end
    end
  end
end
