# frozen_string_literal: true

require "rails_helper"

RSpec.describe StepExecutorService do
  let(:context) { QueryExecution::ExecutionContext.new }

  # Helper to create a mock relation that chains properly
  def mock_relation(_model_class)
    relation = double("ActiveRecord::Relation")
    allow(relation).to receive(:lexical_search).and_return(relation)
    allow(relation).to receive(:where).and_return(relation)
    allow(relation).to receive(:joins).and_return(relation)
    allow(relation).to receive(:includes).and_return(relation)
    allow(relation).to receive(:distinct).and_return(relation)
    allow(relation).to receive(:limit).and_return(relation)
    allow(relation).to receive(:offset).and_return(relation)
    allow(relation).to receive(:order).and_return(relation)
    allow(relation).to receive(:active).and_return(relation)
    allow(relation).to receive(:past).and_return(relation)
    allow(relation).to receive(:main).and_return(relation)
    allow(relation).to receive(:by_body_type).and_return(relation)
    allow(relation).to receive(:by_type).and_return(relation)
    allow(relation).to receive(:date_eq).and_return(relation)
    allow(relation).to receive(:date_before).and_return(relation)
    allow(relation).to receive(:date_after).and_return(relation)
    allow(relation).to receive(:date_between).and_return(relation)
    # New scope names from QueryActions concerns
    allow(relation).to receive(:search).and_return(relation)
    allow(relation).to receive(:by_gender).and_return(relation)
    allow(relation).to receive(:by_occupation).and_return(relation)
    allow(relation).to receive(:by_department).and_return(relation)
    allow(relation).to receive(:by_political_group).and_return(relation)
    allow(relation).to receive(:by_political_orientation).and_return(relation)
    allow(relation).to receive(:by_capacity).and_return(relation)
    allow(relation).to receive(:with_members).and_return(relation)
    allow(relation).to receive(:respond_to?).and_return(true)
    allow(relation).to receive(:to_a).and_return([])
    allow(relation).to receive(:count).and_return(0)
    relation
  end

  describe "#execute" do
    context "with valid step" do
      let(:step) do
        {
          "id" => "find_stakeholders",
          "target_model" => "stakeholder",
          "action" => "search",
          "parameters" => [ "test query" ],
          "limit" => 5
        }
      end

      before do
        relation = mock_relation(An::Stakeholder)
        allow(An::Stakeholder).to receive(:all).and_return(relation)
      end

      it "returns a success result" do
        service = described_class.new(step, context)
        result = service.execute

        expect(result).to be_a(QueryExecution::StepResult)
        expect(result.success?).to be true
        expect(result.step_id).to eq("find_stakeholders")
      end
    end

    context "with invalid model" do
      let(:step) do
        {
          "id" => "invalid_step",
          "target_model" => "unknown_model"
        }
      end

      it "returns a failed result with French message" do
        service = described_class.new(step, context)
        result = service.execute

        expect(result.failed?).to be true
        expect(result.error_message_fr).to include("pas disponible")
      end
    end

    context "with failed dependencies" do
      let(:step) do
        {
          "id" => "dependent_step",
          "target_model" => "stakeholder",
          "depends_on" => [ "failed_step" ]
        }
      end

      before do
        failed_result = QueryExecution::StepResult.failed(
          step_id: "failed_step",
          error_message_fr: "Error"
        )
        context.store_result("failed_step", failed_result)
      end

      it "returns a skipped result" do
        service = described_class.new(step, context)
        result = service.execute

        expect(result.skipped?).to be true
      end
    end

    context "with count action" do
      let(:step) do
        {
          "id" => "count_step",
          "target_model" => "stakeholder",
          "action" => "by_gender",
          "parameters" => [ "woman" ],
          "count" => true
        }
      end

      before do
        relation = mock_relation(An::Stakeholder)
        allow(relation).to receive(:count).and_return(42)
        allow(An::Stakeholder).to receive(:all).and_return(relation)
      end

      it "returns count data" do
        service = described_class.new(step, context)
        result = service.execute

        expect(result.success?).to be true
        expect(result.data).to eq([ { "count" => 42 } ])
      end
    end
  end

  describe "action mapping" do
    describe "stakeholder actions" do
      let(:base_step) do
        {
          "id" => "test_step",
          "target_model" => "stakeholder"
        }
      end
      let(:relation) { mock_relation(An::Stakeholder) }

      before do
        allow(An::Stakeholder).to receive(:all).and_return(relation)
      end

      it "handles search action" do
        step = base_step.merge("action" => "search", "parameters" => [ "query" ])
        service = described_class.new(step, context)

        expect(relation).to receive(:search).with("query").and_return(relation)
        service.execute
      end

      it "handles by_gender action" do
        step = base_step.merge("action" => "by_gender", "parameters" => [ "woman" ])
        service = described_class.new(step, context)

        expect(relation).to receive(:by_gender).with("woman").and_return(relation)
        service.execute
      end

      it "handles by_occupation action" do
        step = base_step.merge("action" => "by_occupation", "parameters" => [ "medecin" ])
        service = described_class.new(step, context)

        expect(relation).to receive(:by_occupation).with("medecin").and_return(relation)
        service.execute
      end
    end

    describe "terms actions" do
      let(:base_step) do
        {
          "id" => "test_step",
          "target_model" => "terms"
        }
      end
      let(:relation) { mock_relation(An::Term) }

      before do
        allow(An::Term).to receive(:all).and_return(relation)
      end

      it "handles no action (nil)" do
        step = base_step.merge("action" => nil)
        service = described_class.new(step, context)
        result = service.execute

        expect(result.success?).to be true
      end

      it "handles by_body_type action" do
        step = base_step.merge("action" => "by_body_type", "parameters" => [ "ASSEMBLEE" ])
        service = described_class.new(step, context)

        expect(relation).to receive(:by_body_type).with("ASSEMBLEE").and_return(relation)
        service.execute
      end

      it "handles by_capacity action" do
        step = base_step.merge("action" => "by_capacity", "parameters" => [ "president" ])
        service = described_class.new(step, context)

        expect(relation).to receive(:by_capacity).with("president").and_return(relation)
        service.execute
      end
    end

    describe "body actions" do
      let(:base_step) do
        {
          "id" => "test_step",
          "target_model" => "body"
        }
      end
      let(:relation) { mock_relation(An::Body) }

      before do
        allow(An::Body).to receive(:all).and_return(relation)
      end

      it "handles search action" do
        step = base_step.merge("action" => "search", "parameters" => [ "commission" ])
        service = described_class.new(step, context)

        expect(relation).to receive(:search).with("commission").and_return(relation)
        service.execute
      end

      it "handles by_type action" do
        step = base_step.merge("action" => "by_type", "parameters" => [ "COMPER" ])
        service = described_class.new(step, context)

        expect(relation).to receive(:by_type).with("COMPER").and_return(relation)
        service.execute
      end

      it "handles with_members action" do
        step = base_step.merge("action" => "with_members")
        service = described_class.new(step, context)

        expect(relation).to receive(:with_members).and_return(relation)
        service.execute
      end
    end
  end

  describe "scope application" do
    let(:step) do
      {
        "id" => "test_step",
        "target_model" => "terms",
        "action" => nil,
        "scope" => "active"
      }
    end
    let(:relation) { mock_relation(An::Term) }

    before do
      allow(An::Term).to receive(:all).and_return(relation)
    end

    it "applies the active scope" do
      service = described_class.new(step, context)

      expect(relation).to receive(:active).and_return(relation)
      service.execute
    end
  end

  describe "date filtering" do
    let(:base_step) do
      {
        "id" => "test_step",
        "target_model" => "terms",
        "action" => nil
      }
    end
    let(:relation) { mock_relation(An::Term) }

    before do
      allow(An::Term).to receive(:all).and_return(relation)
    end

    it "applies EQ date filter" do
      step = base_step.merge("date_op" => "EQ", "date_args" => [ "2024" ])
      service = described_class.new(step, context)

      expect(relation).to receive(:date_eq).with("2024").and_return(relation)
      service.execute
    end

    it "applies BEFORE date filter" do
      step = base_step.merge("date_op" => "BEFORE", "date_args" => [ "2024-01-01" ])
      service = described_class.new(step, context)

      expect(relation).to receive(:date_before).with("2024-01-01").and_return(relation)
      service.execute
    end

    it "applies AFTER date filter" do
      step = base_step.merge("date_op" => "AFTER", "date_args" => [ "2024-01-01" ])
      service = described_class.new(step, context)

      expect(relation).to receive(:date_after).with("2024-01-01").and_return(relation)
      service.execute
    end

    it "applies BETWEEN date filter" do
      step = base_step.merge("date_op" => "BETWEEN", "date_args" => [ "2024-01-01", "2024-12-31" ])
      service = described_class.new(step, context)

      expect(relation).to receive(:date_between).with("2024-01-01", "2024-12-31").and_return(relation)
      service.execute
    end
  end

  describe "pagination" do
    let(:step) do
      {
        "id" => "test_step",
        "target_model" => "stakeholder",
        "limit" => 10,
        "offset" => 5
      }
    end
    let(:relation) { mock_relation(An::Stakeholder) }

    before do
      allow(An::Stakeholder).to receive(:all).and_return(relation)
    end

    it "applies limit and offset" do
      service = described_class.new(step, context)

      expect(relation).to receive(:limit).with(10).and_return(relation)
      expect(relation).to receive(:offset).with(5).and_return(relation)
      service.execute
    end
  end

  describe "error handling" do
    let(:step) do
      {
        "id" => "test_step",
        "target_model" => "stakeholder",
        "action" => "search",
        "parameters" => [ "query" ]
      }
    end

    it "handles database errors gracefully" do
      allow(An::Stakeholder).to receive(:all).and_raise(ActiveRecord::StatementInvalid.new("DB Error"))

      service = described_class.new(step, context)
      result = service.execute

      expect(result.failed?).to be true
      expect(result.error_message_fr).to include("erreur")
    end

    it "handles missing parameters" do
      step_without_params = step.merge("parameters" => [])
      relation = mock_relation(An::Stakeholder)
      allow(An::Stakeholder).to receive(:all).and_return(relation)

      service = described_class.new(step_without_params, context)
      result = service.execute

      expect(result.failed?).to be true
      expect(result.error_message_fr).to include("param")
    end
  end
end
