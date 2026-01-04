# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent::AnswerComposer do
  subject(:answer_composer) { described_class.new }

  let(:agent) { create(:agent, name: "Answer Composer", active: true) }
  let(:agent_version) { create(:agent_version, agent: agent) }
  let(:llm_model) { create(:llm_model) }
  let!(:agent_version_llm_model) { create(:agent_version_llm_model, agent_version: agent_version, llm_model: llm_model, enabled: true) }

  let(:input) do
    {
      question: "Qui est le président de l'Assemblée nationale?",
      results: { "step_1" => [ { "name" => "Test Person" } ] },
      confidence: 5
    }
  end

  before do
    agent.update!(current_agent_version: agent_version)
    allow(described_class).to receive(:agent_name).and_return(agent.normalized_name)
  end

  after do
    described_class.instance_variable_set(:@agent_name, nil)
  end

  def answer_composer_events(action)
    Event.where(category: "agent", action: "answer_composer.#{action}")
  end

  describe "event tracking" do
    let(:mock_response) { double("Response") }
    let(:valid_json_response) do
      {
        "answer" => "Le président est Yaël Braun-Pivet.",
        "sources" => [ "Source officielle" ],
        "confidence_note" => "Basé sur les données actuelles"
      }
    end

    before do
      allow(answer_composer).to receive(:input_validator).and_return(
        double("Validator",
          valid?: true,
          question: input[:question],
          results: input[:results],
          confidence: input[:confidence])
      )
      allow(answer_composer).to receive(:chat)
      allow(answer_composer).to receive(:validate_output).and_return(true)
    end

    describe "on successful composition" do
      before do
        allow(mock_response).to receive(:content).and_return(valid_json_response.to_json)
        allow(answer_composer).to receive(:ask).and_return(mock_response)
      end

      it "creates a started event" do
        expect { answer_composer.call(input) }.to change { answer_composer_events("started").count }.by(1)
      end

      it "creates a completed event" do
        expect { answer_composer.call(input) }.to change { answer_composer_events("completed").count }.by(1)
      end

      it "tracks started event with correct payload" do
        answer_composer.call(input)

        event = answer_composer_events("started").last
        expect(event.category).to eq("agent")
        expect(event.severity).to eq("info")
        expect(event.payload["question"]).to include("président")
        expect(event.payload["result_count"]).to eq(1)
        expect(event.payload["confidence"]).to eq(5)
      end

      it "tracks completed event with correct payload" do
        answer_composer.call(input)

        event = answer_composer_events("completed").last
        expect(event.category).to eq("agent")
        expect(event.severity).to eq("info")
        expect(event.payload["duration_ms"]).to be_a(Integer)
        expect(event.payload["answer_length"]).to be > 0
        expect(event.payload["sources_count"]).to eq(1)
        expect(event.payload["has_confidence_note"]).to be true
      end
    end

    describe "on error" do
      before do
        allow(mock_response).to receive(:content).and_return("invalid json")
        allow(answer_composer).to receive(:ask).and_return(mock_response)
      end

      it "creates an error event" do
        expect { answer_composer.call(input) }.to raise_error(ArgumentError)
          .and change { answer_composer_events("error").count }.by(1)
      end

      it "tracks error event with error details" do
        begin
          answer_composer.call(input)
        rescue ArgumentError
          # Expected
        end

        event = answer_composer_events("error").last
        expect(event.severity).to eq("error")
        expect(event.payload["error_class"]).to be_present
        expect(event.payload["error_message"]).to be_present
        expect(event.payload["duration_ms"]).to be_a(Integer)
      end
    end
  end

  describe "#format_results" do
    before do
      allow(answer_composer).to receive(:input_validator).and_return(
        double("Validator", valid?: true, question: "test", results: results, confidence: 5)
      )
      answer_composer.call(input) rescue nil
    end

    context "with empty results" do
      let(:results) { {} }

      it "returns no results message" do
        expect(answer_composer.send(:format_results)).to eq("No results available")
      end
    end

    context "with small array results" do
      let(:results) { { "step_1" => [ { "id" => 1, "name" => "Test" } ] } }

      it "formats all items inline" do
        formatted = answer_composer.send(:format_results)
        expect(formatted).to include("Step: step_1")
        expect(formatted).to include("id: 1")
        expect(formatted).to include("name: Test")
      end
    end

    context "with large array results" do
      let(:results) { { "step_1" => (1..15).map { |i| { "id" => i, "name" => "Person #{i}" } } } }

      it "shows count and sample" do
        formatted = answer_composer.send(:format_results)
        expect(formatted).to include("15 results found")
        expect(formatted).to include("first 5")
      end
    end
  end
end
