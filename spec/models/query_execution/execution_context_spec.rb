# frozen_string_literal: true

require "rails_helper"

RSpec.describe QueryExecution::ExecutionContext do
  let(:context) { described_class.new }

  describe "#store_result" do
    it "stores a result by step_id" do
      result = QueryExecution::StepResult.success(step_id: "step1", data: [])
      context.store_result("step1", result)

      expect(context.get_result("step1")).to eq(result)
    end

    it "marks execution as failed when storing a failed result" do
      result = QueryExecution::StepResult.failed(
        step_id: "step1",
        error_message_fr: "Error"
      )
      context.store_result("step1", result)

      expect(context.execution_failed?).to be true
    end
  end

  describe "#get_result" do
    it "returns nil for unknown step_id" do
      expect(context.get_result("unknown")).to be_nil
    end
  end

  describe "#all_results" do
    it "returns all stored results as a hash" do
      result1 = QueryExecution::StepResult.success(step_id: "step1", data: [ 1 ])
      result2 = QueryExecution::StepResult.success(step_id: "step2", data: [ 2 ])

      context.store_result("step1", result1)
      context.store_result("step2", result2)

      expect(context.all_results).to eq({
        "step1" => result1,
        "step2" => result2
      })
    end
  end

  describe "#results_data" do
    it "returns data from successful results" do
      result1 = QueryExecution::StepResult.success(step_id: "step1", data: [ 1 ])
      result2 = QueryExecution::StepResult.failed(step_id: "step2", error_message_fr: "Error")

      context.store_result("step1", result1)
      context.store_result("step2", result2)

      expect(context.results_data).to eq({
        "step1" => [ 1 ],
        "step2" => nil
      })
    end
  end

  describe "#execution_failed?" do
    it "returns false when no results" do
      expect(context.execution_failed?).to be false
    end

    it "returns false when all results succeed" do
      result = QueryExecution::StepResult.success(step_id: "step1", data: [])
      context.store_result("step1", result)

      expect(context.execution_failed?).to be false
    end
  end

  describe "#failed_results" do
    it "returns only failed results" do
      result1 = QueryExecution::StepResult.success(step_id: "step1", data: [])
      result2 = QueryExecution::StepResult.failed(step_id: "step2", error_message_fr: "Error")
      result3 = QueryExecution::StepResult.skipped(step_id: "step3")

      context.store_result("step1", result1)
      context.store_result("step2", result2)
      context.store_result("step3", result3)

      expect(context.failed_results).to eq([ result2 ])
    end
  end

  describe "#successful_results" do
    it "returns only successful results" do
      result1 = QueryExecution::StepResult.success(step_id: "step1", data: [])
      result2 = QueryExecution::StepResult.failed(step_id: "step2", error_message_fr: "Error")

      context.store_result("step1", result1)
      context.store_result("step2", result2)

      expect(context.successful_results).to eq([ result1 ])
    end
  end

  describe "#step_ids" do
    it "returns all step IDs" do
      result1 = QueryExecution::StepResult.success(step_id: "step1", data: [])
      result2 = QueryExecution::StepResult.success(step_id: "step2", data: [])

      context.store_result("step1", result1)
      context.store_result("step2", result2)

      expect(context.step_ids).to contain_exactly("step1", "step2")
    end
  end

  describe "thread safety" do
    it "handles concurrent writes safely" do
      threads = 10.times.map do |i|
        Thread.new do
          result = QueryExecution::StepResult.success(step_id: "step#{i}", data: [ i ])
          context.store_result("step#{i}", result)
        end
      end

      threads.each(&:join)

      expect(context.step_ids.size).to eq(10)
    end
  end
end
