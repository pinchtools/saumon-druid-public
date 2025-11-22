require 'rails_helper'

RSpec.describe Agents::Outputs::QueryPlannerOutput, type: :model do
  describe 'validations' do
    let(:valid_step) do
      {
        "id" => "test_step",
        "target_model" => "an_stakeholders",
        "filters" => [
          {
            "field" => "name",
            "op" => "LIKE",
            "value" => "%test%"
          }
        ]
      }
    end

    let(:valid_attributes) do
      {
        steps: [ valid_step ]
      }
    end

    subject { described_class.new(valid_attributes) }

    it 'is valid with valid attributes' do
      expect(subject).to be_valid
    end

    describe 'steps validation' do
      it 'requires steps to be present' do
        subject.steps = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Query plan must contain 'steps'")
      end

      it 'requires steps to be an array with at least one element' do
        subject.steps = []
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("must contain at least one step")
      end

      it 'requires each step to be a hash' do
        subject.steps = [ "invalid" ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1 must be a hash")
      end

      it 'requires id in each step' do
        subject.steps = [ { "target_model" => "an_stakeholders" } ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1: id is required")
      end

      it 'requires target_model in each step' do
        subject.steps = [ { "id" => "test_step" } ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1: target_model is required")
      end

      it 'validates target_model against allowed values' do
        subject.steps = [ { "id" => "test_step", "target_model" => "invalid_model" } ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1: target_model must be one of an_stakeholders, an_bodies, an_body_types, an_terms, an_stakeholder_addresses")
      end

      it 'validates limit is between 1 and 50' do
        subject.steps = [ valid_step.merge("limit" => 0) ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1: limit must be an integer between 1 and 50")

        subject.steps = [ valid_step.merge("limit" => 51) ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1: limit must be an integer between 1 and 50")

        subject.steps = [ valid_step.merge("limit" => 25) ]
        expect(subject).to be_valid
      end

      it 'validates offset is non-negative' do
        subject.steps = [ valid_step.merge("offset" => -1) ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1: offset must be a non-negative integer")

        subject.steps = [ valid_step.merge("offset" => 0) ]
        expect(subject).to be_valid
      end

      it 'validates filter_logic is AND or OR' do
        subject.steps = [ valid_step.merge("filter_logic" => "INVALID") ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1: filter_logic must be 'AND' or 'OR'")

        subject.steps = [ valid_step.merge("filter_logic" => "AND") ]
        expect(subject).to be_valid
      end
    end

    describe 'filters validation' do
      it 'requires filters to be an array' do
        step = valid_step.merge("filters" => "invalid")
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1: filters must be an array")
      end

      it 'requires each filter to be a hash' do
        step = valid_step.merge("filters" => [ "invalid" ])
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1, Filter 1: must be a hash")
      end

      it 'requires field, op, and value in each filter' do
        step = valid_step.merge("filters" => [ { "field" => "name" } ])
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1, Filter 1: must have field, op, and value")
      end

      it 'validates operator against allowed values' do
        step = valid_step.merge("filters" => [ { "field" => "name", "op" => "INVALID", "value" => "test" } ])
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1, Filter 1: op must be one of =, !=, >, <, >=, <=, IN, LIKE, ILIKE, BETWEEN")
      end
    end

    describe 'joins validation' do
      it 'requires joins to be an array' do
        step = valid_step.merge("joins" => "invalid")
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1: joins must be an array")
      end

      it 'requires each join to be a hash' do
        step = valid_step.merge("joins" => [ "invalid" ])
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1, Join 1: must be a hash")
      end

      it 'requires model and on in each join' do
        step = valid_step.merge("joins" => [ { "model" => "an_bodies" } ])
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1, Join 1: must have model and on")
      end

      it 'validates join model against allowed values' do
        step = valid_step.merge("joins" => [ { "model" => "invalid_model", "on" => "id" } ])
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1, Join 1: model must be one of an_stakeholders, an_bodies, an_body_types, an_terms, an_stakeholder_addresses")
      end

      it 'validates join type against allowed values' do
        step = valid_step.merge("joins" => [ { "model" => "an_bodies", "on" => "id", "type" => "INVALID" } ])
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1, Join 1: type must be one of INNER, LEFT, RIGHT")
      end
    end

    describe 'filter value lookup validation' do
      it 'validates lookup object in filter value must have step_id and field' do
        step = valid_step.merge("filters" => [
          {
            "field" => "an_stakeholder_id",
            "op" => "=",
            "value" => { "step_id" => "step1" }  # missing field
          }
        ])
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1, Filter 1: lookup value must have step_id and field")
      end

      it 'validates lookup mode in filter value against allowed values' do
        step = valid_step.merge("filters" => [
          {
            "field" => "an_stakeholder_id",
            "op" => "=",
            "value" => {
              "step_id" => "step1",
              "field" => "id",
              "mode" => "invalid"
            }
          }
        ])
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1, Filter 1: lookup mode must be 'first' or 'all'")
      end

      it 'accepts valid lookup object in filter value' do
        step = valid_step.merge("filters" => [
          {
            "field" => "an_stakeholder_id",
            "op" => "=",
            "value" => {
              "step_id" => "step1",
              "field" => "id",
              "mode" => "first"
            }
          }
        ])
        subject.steps = [ step ]
        expect(subject).to be_valid
      end

      it 'accepts simple values in filter value' do
        step = valid_step.merge("filters" => [
          {
            "field" => "name",
            "op" => "=",
            "value" => "test_value"
          }
        ])
        subject.steps = [ step ]
        expect(subject).to be_valid
      end
    end

    describe 'aggregation validation' do
      it 'requires aggregation to be a hash' do
        step = valid_step.merge("aggregation" => "invalid")
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1: aggregation must be a hash")
      end

      it 'requires function and field in aggregation' do
        step = valid_step.merge("aggregation" => { "function" => "COUNT" })
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1: aggregation must have function and field")
      end

      it 'validates aggregation function against allowed values' do
        step = valid_step.merge("aggregation" => { "function" => "INVALID", "field" => "id" })
        subject.steps = [ step ]
        expect(subject).not_to be_valid
        expect(subject.errors[:steps]).to include("Step 1: aggregation function must be one of COUNT, SUM, AVG, MAX, MIN")
      end
    end
  end
end
