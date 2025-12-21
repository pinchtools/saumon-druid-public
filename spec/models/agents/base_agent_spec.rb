require 'rails_helper'

RSpec.describe Agents::BaseAgent do
  subject(:base_agent) { described_class.new }

  let(:agent) { create(:agent, name: "Test Agent", active: true) }
  let(:agent_version) { create(:agent_version, agent: agent, hyperparams: {}, instructions: "Test instructions") }
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
      expect(base_agent.name).to eq(agent.name)
    end
  end

  describe '#normalized_name' do
    it 'returns agent normalized name' do
      expect(base_agent.normalized_name).to eq(agent.normalized_name)
    end
  end

  describe '#version' do
    it 'returns current version number' do
      expect(base_agent.version).to eq(agent_version.version)
    end
  end

  describe '#primary_model' do
    it 'returns first enabled model' do
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

  describe '#ask' do
    let(:mock_chat) { instance_double(RubyLLM::Chat) }
    let(:mock_response) { instance_double("Response", raw: mock_raw_response, content: "{}") }
    let(:mock_raw_response) do
      instance_double(
        Faraday::Response,
        status: 200,
        headers: { "content-type" => "application/json" },
        body: {
          "id" => "gen-123",
          "model" => "test-model",
          "choices" => [
            { "message" => { "role" => "assistant", "content" => "Hello world" } }
          ],
          "usage" => { "prompt_tokens" => 10, "completion_tokens" => 20 }
        }
      )
    end

    before do
      allow(RubyLLM).to receive(:chat).and_return(mock_chat)
      allow(mock_chat).to receive(:with_instructions).and_return(mock_chat)
      allow(mock_chat).to receive(:with_temperature).and_return(mock_chat)
      allow(mock_chat).to receive(:with_params).and_return(mock_chat)
      allow(mock_chat).to receive(:ask).and_return(mock_response)
      allow(mock_raw_response).to receive(:is_a?).with(Faraday::Response).and_return(true)
      base_agent.send(:chat)
    end

    after { Current.reset }

    it "calls chat.ask and returns response" do
      response = base_agent.send(:ask, "test question")

      expect(mock_chat).to have_received(:ask).with("test question")
      expect(response).to eq(mock_response)
    end

    it "creates request event before LLM call" do
      expect { base_agent.send(:ask, "test") }.to change(Event, :count).by(2)

      request_event = Event.find_by(action: "request")

      expect(request_event.category).to eq("llm")
      expect(request_event.severity).to eq("info")
      expect(request_event.payload["agent"]).to eq(agent.normalized_name)
      expect(request_event.payload["agent_version"]).to eq(agent_version.version)
      expect(request_event.payload["model"]).to eq(llm_model.external_id)
    end

    it "creates response event after LLM call" do
      base_agent.send(:ask, "test")

      response_event = Event.find_by(action: "response")

      expect(response_event.category).to eq("llm")
      expect(response_event.severity).to eq("info")
      expect(response_event.payload["status"]).to eq(200)
      expect(response_event.payload["body"]["id"]).to eq("gen-123")
      expect(response_event.payload["body"]["usage"]).to be_present
    end

    it "filters content from response payload" do
      base_agent.send(:ask, "test")

      response_event = Event.find_by(action: "response")
      choice = response_event.payload.dig("body", "choices", 0, "message")

      expect(choice).not_to have_key("content")
      expect(choice["role"]).to eq("assistant")
    end

    it "captures Current context in events" do
      Current.session_id = SecureRandom.uuid
      Current.request_id = SecureRandom.uuid
      Current.job_id = SecureRandom.uuid

      base_agent.send(:ask, "test")

      Event.where(category: "llm").each do |event|
        expect(event.session_id).to eq(Current.session_id)
        expect(event.request_id).to eq(Current.request_id)
        expect(event.job_id).to eq(Current.job_id)
      end
    end
  end

  describe '#filter_response_payload' do
    it "returns empty hash for non-Faraday::Response" do
      result = base_agent.send(:filter_response_payload, { "foo" => "bar" })

      expect(result).to eq({})
    end

    it "extracts status, headers, and filtered body" do
      raw = instance_double(
        Faraday::Response,
        status: 200,
        headers: { "x-request-id" => "abc" },
        body: { "id" => "123", "choices" => [] }
      )
      allow(raw).to receive(:is_a?).with(Faraday::Response).and_return(true)

      result = base_agent.send(:filter_response_payload, raw)

      expect(result[:status]).to eq(200)
      expect(result[:headers]).to eq({ "x-request-id" => "abc" })
      expect(result[:body]["id"]).to eq("123")
    end

    it "removes content from all choices" do
      raw = instance_double(
        Faraday::Response,
        status: 200,
        headers: {},
        body: {
          "choices" => [
            { "index" => 0, "message" => { "role" => "assistant", "content" => "secret content" } },
            { "index" => 1, "message" => { "role" => "assistant", "content" => "more content" } }
          ]
        }
      )
      allow(raw).to receive(:is_a?).with(Faraday::Response).and_return(true)

      result = base_agent.send(:filter_response_payload, raw)

      result[:body]["choices"].each do |choice|
        expect(choice["message"]).not_to have_key("content")
        expect(choice["message"]["role"]).to eq("assistant")
      end
    end
  end

  describe '#parse_and_validate_json_response' do
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
