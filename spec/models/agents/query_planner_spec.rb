require 'rails_helper'

RSpec.describe Agents::QueryPlanner do
  let(:input) do
    {
      question: "Who are the current presidents of France?",
      trace_id: "test-trace",
      message_id: "test-message"
    }
  end

  describe '#agent_name' do
    it 'returns query_planner' do
      expect(described_class.agent_name).to eq('query_planner')
    end
  end

  describe '#initialize' do
    before do
      # Mock the agent lookup
      agent = double('Agent', current_agent_version: double('Version', enabled_llm_models: [ double('Model') ]))
      allow(Agent).to receive_message_chain(:with_name, :active, :first).and_return(agent)
    end

    it 'initializes successfully' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe '#call' do
    let(:planner) { described_class.allocate }
    let(:mock_chat) { double('Chat') }
    let(:mock_response) { double('Response') }

    before do
      # Mock the initialization dependencies
      planner.instance_variable_set(:@agent, double('Agent'))
      planner.instance_variable_set(:@current_version, double('Version'))
      planner.instance_variable_set(:@enabled_models, [ double('Model') ])

      # Mock input validation
      allow(planner).to receive(:input_validator).and_return(double('Validator', valid?: true, question: 'test question'))
      allow(planner).to receive(:chat).and_return(mock_chat)
      # Mock output validation
      allow(planner).to receive(:validate_output).and_return(true)
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
        result = planner.call(input)
        expect(result).to be_a(Hash)
        expect(result["steps"]).to be_a(Array)
        expect(result["steps"].first["target_model"]).to eq('an_stakeholders')
      end
    end

    context 'with invalid input' do
      it 'raises ArgumentError for input validation failure' do
        invalid_validator = double('Validator', valid?: false, errors: double('Errors', full_messages: [ 'Question is too short' ]))
        allow(planner).to receive(:input_validator).and_return(invalid_validator)

        expect { planner.call(input) }.to raise_error(ArgumentError, /Input validation failed/)
      end
    end

    context 'with invalid LLM response' do
      before do
        allow(mock_response).to receive(:content).and_return('invalid json')
        allow(mock_chat).to receive(:ask).and_return(mock_response)
      end

      it 'raises ArgumentError for invalid JSON' do
        expect { planner.call(input) }.to raise_error(ArgumentError, /Invalid JSON response/)
      end
    end

    context 'with JSON in markdown blocks' do
      before do
        json_content = {
          "steps" => [
            {
              "target_model" => "an_stakeholders",
              "filters" => []
            }
          ]
        }
        markdown_response = "```json\n#{json_content.to_json}\n```"
        allow(mock_response).to receive(:content).and_return(markdown_response)
        allow(mock_chat).to receive(:ask).and_return(mock_response)
      end

      it 'extracts JSON from markdown blocks' do
        result = planner.call(input)
        expect(result).to be_a(Hash)
        expect(result["steps"]).to be_a(Array)
      end
    end
  end
end
