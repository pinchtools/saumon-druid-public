# frozen_string_literal: true

require "rails_helper"

RSpec.describe QueryExecution::StepResult do
  describe ".success" do
    it "creates a success result with data" do
      result = described_class.success(step_id: "test_step", data: [ { id: 1 } ])

      expect(result.success?).to be true
      expect(result.failed?).to be false
      expect(result.skipped?).to be false
      expect(result.step_id).to eq("test_step")
      expect(result.data).to eq([ { id: 1 } ])
    end
  end

  describe ".failed" do
    it "creates a failed result with French message" do
      result = described_class.failed(
        step_id: "test_step",
        error_message_fr: "Une erreur est survenue",
        error_details: { code: "ERR001" }
      )

      expect(result.failed?).to be true
      expect(result.success?).to be false
      expect(result.skipped?).to be false
      expect(result.error_message_fr).to eq("Une erreur est survenue")
      expect(result.error_details).to eq({ code: "ERR001" })
    end
  end

  describe ".skipped" do
    it "creates a skipped result with default reason" do
      result = described_class.skipped(step_id: "test_step")

      expect(result.skipped?).to be true
      expect(result.success?).to be false
      expect(result.failed?).to be false
      expect(result.error_message_fr).to include("tape pr")
    end

    it "creates a skipped result with custom reason" do
      result = described_class.skipped(step_id: "test_step", reason: "Custom reason")

      expect(result.error_message_fr).to eq("Custom reason")
    end
  end

  describe "#to_h" do
    it "converts to hash with compact values" do
      result = described_class.success(step_id: "test_step", data: [ { id: 1 } ])
      hash = result.to_h

      expect(hash).to eq({
        step_id: "test_step",
        status: :success,
        data: [ { id: 1 } ]
      })
    end
  end

  describe "immutability" do
    it "freezes the object after creation" do
      result = described_class.success(step_id: "test", data: [])

      expect(result).to be_frozen
    end
  end

  describe "validation" do
    it "raises error for invalid status" do
      expect {
        described_class.new(step_id: "test", status: :invalid)
      }.to raise_error(ArgumentError, /Invalid status/)
    end
  end
end
