require 'rails_helper'

RSpec.describe Agent::QueryPlanner do
  subject(:query_planner) { described_class.new }

  let(:agent) { create(:agent, name: "Query Planner", active: true) }
  let(:agent_version) { create(:agent_version, agent: agent) }
  let(:llm_model) { create(:llm_model) }
  let!(:agent_version_llm_model) { create(:agent_version_llm_model, agent_version: agent_version, llm_model: llm_model, enabled: true) }

  let(:input) do
    {
      question: "Who are the current presidents of France?",
      trace_id: "test-trace",
      message_id: "test-message"
    }
  end

  before do
    agent.update!(current_agent_version: agent_version)
    allow(described_class).to receive(:agent_name).and_return(agent.normalized_name)
  end

  after do
    described_class.instance_variable_set(:@agent_name, nil)
  end

  describe '#agent_name' do
    it 'returns query_planner' do
      expect(described_class.agent_name).to eq('query_planner')
    end
  end

  describe '#initialize' do
    it 'initializes successfully' do
      expect { query_planner }.not_to raise_error
      expect(query_planner.agent).to eq(agent)
      expect(query_planner.current_version).to eq(agent_version)
      expect(query_planner.enabled_models).to include(llm_model)
    end
  end

  describe '#call' do
    let(:mock_chat) { double('Chat') }
    let(:mock_response) { double('Response') }

    before do
      allow(query_planner).to receive(:input_validator).and_return(double('Validator', valid?: true, question: 'test question'))
      allow(query_planner).to receive(:chat).and_return(mock_chat)

      allow(query_planner).to receive(:validate_output).and_return(true)
    end

    context 'with valid input' do
      let(:valid_json_response) do
        {
          "steps" => [
            {
              "target_model" => "an_stakeholders",
              "filters" => [
                {
                  "field" => "role",
                  "op" => "=",
                  "value" => "President"
                }
              ],
              "limit" => 1,
              "order" => "start_date DESC",
              "context_label" => "current_presidents"
            }
          ]
        }
      end

      before do
        allow(mock_response).to receive(:content).and_return(valid_json_response.to_json)
        allow(mock_chat).to receive(:ask).and_return(mock_response)
      end

      it 'returns a valid hash structure' do
        result = query_planner.call(input)
        expect(result).to eq(valid_json_response)
      end
    end

    context 'with invalid input' do
      it 'raises ArgumentError for input validation failure' do
        invalid_validator = double('Validator', valid?: false, errors: double('Errors', full_messages: [ 'Question is too short' ]))
        allow(query_planner).to receive(:input_validator).and_return(invalid_validator)

        expect { query_planner.call(input) }.to raise_error(ArgumentError, /Input validation failed/)
      end
    end

    context 'with invalid LLM response' do
      before do
        allow(mock_response).to receive(:content).and_return('invalid json')
        allow(mock_chat).to receive(:ask).and_return(mock_response)
      end

      it 'raises ArgumentError for invalid JSON' do
        expect { query_planner.call(input) }.to raise_error(ArgumentError, /Invalid JSON response/)
      end
    end
  end
end
