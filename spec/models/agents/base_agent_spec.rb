require 'rails_helper'

RSpec.describe Agents::BaseAgent do
  let(:agent) { create(:agent, name: "Test Agent", active: true) }
  let(:agent_version) { create(:agent_version, agent: agent) }
  let(:llm_model) { create(:llm_model) }
  let!(:agent_version_llm_model) { create(:agent_version_llm_model, agent_version: agent_version, llm_model: llm_model, enabled: true) }

  before do
    agent.update!(current_agent_version: agent_version)
    allow(described_class).to receive(:agent_name).and_return(agent.normalized_name)
  end

  after do
    described_class.instance_variable_set(:@agent_name, nil)
  end

  describe '#initialize' do
    context 'with valid agent' do
      it 'loads agent data successfully' do
        base_agent = described_class.new
        expect(base_agent.agent).to eq(agent)
        expect(base_agent.current_version).to eq(agent_version)
        expect(base_agent.enabled_models).to include(llm_model)
      end
    end

    context 'when agent not found' do
      before do
        allow(described_class).to receive(:agent_name).and_return("nonexistent")
      end

      it 'raises ArgumentError' do
        expect { described_class.new }.to raise_error(ArgumentError, "Agent 'nonexistent' not found or inactive")
      end
    end

    context 'when agent inactive' do
      before do
        agent.update!(active: false)
      end

      it 'raises ArgumentError' do
        expect { described_class.new }.to raise_error(ArgumentError, /not found or inactive/)
      end
    end

    context 'when no current version' do
      before do
        agent.update!(current_agent_version: nil)
      end

      it 'raises ArgumentError' do
        expect { described_class.new }.to raise_error(ArgumentError, /has no current version/)
      end
    end

    context 'when no enabled models' do
      before do
        agent_version_llm_model.update!(enabled: false)
      end

      it 'raises ArgumentError' do
        expect { described_class.new }.to raise_error(ArgumentError, /has no enabled models/)
      end
    end
  end

  describe '#name' do
    it 'returns agent name' do
      base_agent = described_class.new
      expect(base_agent.name).to eq(agent.name)
    end
  end

  describe '#normalized_name' do
    it 'returns agent normalized name' do
      base_agent = described_class.new
      expect(base_agent.normalized_name).to eq(agent.normalized_name)
    end
  end

  describe '#version' do
    it 'returns current version number' do
      base_agent = described_class.new
      expect(base_agent.version).to eq(agent_version.version)
    end
  end

  describe '#primary_model' do
    it 'returns first enabled model' do
      base_agent = described_class.new
      expect(base_agent.primary_model).to eq(llm_model)
    end
  end

  describe '.agent_name' do
    before do
      described_class.instance_variable_set(:@agent_name, nil)
      allow(described_class).to receive(:agent_name).and_call_original
    end

    context 'when called with parameter' do
      it 'sets and returns agent name' do
        expect(described_class.agent_name("test")).to eq("test")
        expect(described_class.agent_name).to eq("test")
      end
    end

    context 'when no parameter and no cached name' do
      before do
        allow(described_class).to receive(:name).and_return("Agents::TestAgent")
      end

      it 'returns underscored class name' do
        expect(described_class.agent_name).to eq("test_agent")
      end
    end
  end

  describe '#extract_json_from_response' do
    let(:base_agent) { described_class.new }

    it 'extracts JSON from ```json markdown blocks' do
      content = "```json\n{\"test\": true}\n```"
      result = base_agent.send(:extract_json_from_response, content)
      expect(result).to eq('{"test": true}')
    end

    it 'extracts JSON from ``` markdown blocks' do
      content = "```\n{\"test\": true}\n```"
      result = base_agent.send(:extract_json_from_response, content)
      expect(result).to eq('{"test": true}')
    end

    it 'returns content as-is if no markdown blocks' do
      content = '{"test": true}'
      result = base_agent.send(:extract_json_from_response, content)
      expect(result).to eq('{"test": true}')
    end

    it 'handles content with extra whitespace' do
      content = "  ```json\n  {\"test\": true}  \n```  "
      result = base_agent.send(:extract_json_from_response, content)
      expect(result).to eq('{"test": true}')
    end

    it 'does not modify content with partial markdown syntax' do
      content = "```json\n{\"test\": true}"
      result = base_agent.send(:extract_json_from_response, content)
      expect(result).to eq("```json\n{\"test\": true}")
    end

    it 'handles nested code blocks correctly' do
      content = "```json\n{\"code\": \"```inner```\"}\n```"
      result = base_agent.send(:extract_json_from_response, content)
      expect(result).to eq('{"code": "```inner```"}')
    end
  end

  describe '#parse_and_validate_json_response' do
    let(:base_agent) { described_class.new }
    let(:response) { double('response', content: content) }

    context 'with valid JSON' do
      let(:content) { '{"test": true}' }

      it 'parses and validates JSON response' do
        allow(base_agent).to receive(:validate_output).and_return(true)
        result = base_agent.send(:parse_and_validate_json_response, response)
        expect(result).to eq({ "test" => true })
      end
    end

    context 'with JSON in markdown blocks' do
      let(:content) { "```json\n{\"test\": true}\n```" }

      it 'extracts and parses JSON from markdown blocks' do
        allow(base_agent).to receive(:validate_output).and_return(true)
        result = base_agent.send(:parse_and_validate_json_response, response)
        expect(result).to eq({ "test" => true })
      end
    end

    context 'with invalid JSON' do
      let(:content) { 'invalid json' }

      it 'raises ArgumentError for invalid JSON' do
        expect { base_agent.send(:parse_and_validate_json_response, response) }
          .to raise_error(ArgumentError, /Invalid JSON response from LLM/)
      end
    end

    context 'with validation failure' do
      let(:content) { '{"test": true}' }

      it 'raises ArgumentError when validation fails' do
        allow(base_agent).to receive(:validate_output).and_raise(ArgumentError, "Validation failed")
        expect { base_agent.send(:parse_and_validate_json_response, response) }
          .to raise_error(ArgumentError, "Validation failed")
      end
    end
  end
end
