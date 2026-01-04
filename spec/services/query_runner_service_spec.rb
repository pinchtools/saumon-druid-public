require 'rails_helper'

RSpec.describe QueryRunnerService do
  let(:simple_query_plan) do
    {
      "steps" => [
        {
          "id" => "find_stakeholders",
          "target_model" => "an_stakeholders",
          "filters" => [
            {
              "field" => "last_name",
              "op" => "=",
              "value" => "Macron"
            }
          ],
          "limit" => 5,
          "context_label" => "presidents"
        }
      ]
    }
  end

  let(:complex_query_plan) do
    {
      "steps" => [
        {
          "id" => "find_body",
          "target_model" => "an_bodies",
          "filters" => [
            {
              "field" => "name",
              "op" => "LIKE",
              "value" => "%Presidency%"
            }
          ],
          "limit" => 1
        },
        {
          "id" => "find_terms",
          "target_model" => "an_terms",
          "filters" => [
            {
              "field" => "body_id",
              "op" => "=",
              "value" => {
                "step_id" => "find_body",
                "field" => "id",
                "mode" => "first"
              }
            }
          ],
          "limit" => 10,
          "context_label" => "presidential_terms"
        }
      ]
    }
  end

  describe '#initialize' do
    it 'stores the query plan' do
      service = described_class.new(simple_query_plan)
      expect(service.instance_variable_get(:@query_plan)).to eq(simple_query_plan)
    end
  end

  describe '#execute' do
    context 'with invalid query plan' do
      it 'raises error for non-Hash input' do
        service = described_class.new("invalid")
        expect { service.execute }.to raise_error(QueryRunnerService::QueryError, /must be a Hash/)
      end

      it 'raises error for query plan without steps' do
        invalid_plan = { "other_key" => "value" }
        service = described_class.new(invalid_plan)
        expect { service.execute }.to raise_error(QueryRunnerService::QueryError, /must contain 'steps'/)
      end

      it 'raises error for empty steps' do
        invalid_plan = { "steps" => [] }
        service = described_class.new(invalid_plan)
        expect { service.execute }.to raise_error(QueryRunnerService::QueryError, /must contain at least one step/)
      end
    end

    context 'with valid query plan' do
      let(:service) { described_class.new(simple_query_plan) }
      let(:mock_stakeholder) { double('Stakeholder', attributes: { 'id' => 1, 'last_name' => 'Macron' }) }
      let(:mock_query) { double('Query') }

      before do
        # Mock the model class resolution
        stub_const('An::Stakeholder', double('An::Stakeholder'))
        allow(An::Stakeholder).to receive(:column_names).and_return([ 'id', 'first_name', 'last_name' ])
        allow(An::Stakeholder).to receive(:where).and_return(mock_query)
        allow(mock_query).to receive(:limit).and_return(mock_query)
        allow(mock_query).to receive(:offset).and_return(mock_query)
        allow(mock_query).to receive(:to_a).and_return([ mock_stakeholder ])
      end

      it 'executes successfully and returns context' do
        result = service.execute
        expect(result).to be_a(Hash)
        expect(result).to have_key('presidents')
      end
    end

    context 'with step dependencies' do
      let(:service) { described_class.new(complex_query_plan) }
      let(:mock_body) { double('Body', attributes: { 'id' => 1, 'name' => 'French Presidency' }) }
      let(:mock_term) { double('Term', attributes: { 'id' => 1, 'body_id' => 1, 'stakeholder_id' => 1 }) }
      let(:mock_query) { double('Query') }

      before do
        # Mock An::Body
        stub_const('An::Body', double('An::Body'))
        allow(An::Body).to receive(:column_names).and_return([ 'id', 'name' ])
        allow(An::Body).to receive(:where).and_return(mock_query)

        # Mock An::Term
        stub_const('An::Term', double('An::Term'))
        allow(An::Term).to receive(:column_names).and_return([ 'id', 'body_id', 'stakeholder_id' ])
        allow(An::Term).to receive(:where).and_return(mock_query)

        # Mock query chain
        allow(mock_query).to receive(:limit).and_return(mock_query)
        allow(mock_query).to receive(:offset).and_return(mock_query)
        allow(mock_query).to receive(:to_a).and_return([ mock_body ], [ mock_term ])
      end

      it 'resolves dependencies correctly' do
        result = service.execute
        expect(result).to have_key('presidential_terms')
      end
    end
  end

  describe '#get_model_class' do
    let(:service) { described_class.new(simple_query_plan) }

    it 'resolves valid model names' do
      QueryRunnerService::MODEL_MAPPING.each do |model_name, class_name|
        # Mock the class
        stub_const(class_name, Class.new)

        result = service.send(:get_model_class, model_name)
        expect(result.name).to eq(class_name)
      end
    end

    it 'raises error for invalid model name' do
      expect { service.send(:get_model_class, 'invalid_model') }
        .to raise_error(QueryRunnerService::ModelNotFoundError, /Unknown model/)
    end
  end

  describe '#build_condition' do
    let(:service) { described_class.new(simple_query_plan) }

    it 'builds equality condition' do
      result = service.send(:build_condition, 'name', '=', 'test')
      expect(result).to eq({ 'name' => 'test' })
    end

    it 'builds inequality condition' do
      result = service.send(:build_condition, 'name', '!=', 'test')
      expect(result).to eq([ "name != ?", 'test' ])
    end

    it 'builds comparison conditions' do
      [ '>', '<', '>=', '<=' ].each do |op|
        result = service.send(:build_condition, 'age', op, 25)
        expect(result).to eq([ "age #{op} ?", 25 ])
      end
    end

    it 'builds IN condition' do
      result = service.send(:build_condition, 'status', 'IN', [ 'active', 'pending' ])
      expect(result).to eq({ 'status' => [ 'active', 'pending' ] })
    end

    it 'builds LIKE condition' do
      result = service.send(:build_condition, 'name', 'LIKE', '%pattern%')
      expect(result).to eq([ "name LIKE ?", '%pattern%' ])
    end

    it 'builds BETWEEN condition' do
      result = service.send(:build_condition, 'age', 'BETWEEN', [ 18, 65 ])
      expect(result).to eq([ "age BETWEEN ? AND ?", 18, 65 ])
    end

    it 'raises error for unsupported operator' do
      expect { service.send(:build_condition, 'name', 'INVALID', 'test') }
        .to raise_error(QueryRunnerService::QueryError, /Unsupported operator/)
    end
  end

  describe '#lookup_value' do
    let(:service) { described_class.new(simple_query_plan) }
    let(:lookup_ref) do
      {
        "step_id" => 'test_step',
        "field" => 'id',
        "mode" => 'first'
      }
    end

    before do
      service.instance_variable_set(:@step_results, {
        'test_step' => [
          { 'id' => 1, 'name' => 'Test 1' },
          { 'id' => 2, 'name' => 'Test 2' }
        ]
      })
    end

    it 'returns first value for first mode' do
      result = service.send(:lookup_value, lookup_ref, nil)
      expect(result).to eq(1)
    end

    it 'returns all values for all mode' do
      lookup_ref["mode"] = 'all'
      result = service.send(:lookup_value, lookup_ref, nil)
      expect(result).to eq([ 1, 2 ])
    end

    it 'raises error for missing step' do
      lookup_ref["step_id"] = 'missing_step'
      expect { service.send(:lookup_value, lookup_ref, nil) }
        .to raise_error(QueryRunnerService::LookupError, /not found or not executed/)
    end

    it 'returns nil for empty results' do
      service.instance_variable_set(:@step_results, { 'test_step' => [] })
      result = service.send(:lookup_value, lookup_ref, nil)
      expect(result).to be_nil
    end
  end
end
