# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Llm::ImporterService do
  subject { described_class.new }

  describe '#call' do
    let(:yaml_content) do
      {
        'openai' => [ { 'id' => 'gpt-4', 'tier' => 'premium' } ],
        'anthropic' => [ { 'id' => 'claude-3', 'tier' => 'standard' } ]
      }
    end

    before do
      allow(subject).to receive(:yaml).and_return(yaml_content)
      allow(RubyLLM.models).to receive(:refresh!)
      allow_any_instance_of(Llm::ModelImporter).to receive(:call).and_return(true)
    end

    context 'with valid models configuration' do
      it 'returns true on successful import' do
        expect(subject.call).to be(true)
      end

      it 'refreshes RubyLLM models before importing' do
        subject.call

        expect(RubyLLM.models).to have_received(:refresh!)
      end

      it 'processes all models from configuration' do
        allow(Llm::ModelImporter).to receive_message_chain(:new, :call)
        expect(Llm::ModelImporter).to receive(:new).with({ 'id' => 'gpt-4', 'tier' => 'premium' })
        expect(Llm::ModelImporter).to receive(:new).with({ 'id' => 'claude-3', 'tier' => 'standard' })

        subject.call
      end
    end

    context 'with empty configuration' do
      let(:yaml_content) { {} }

      it 'returns true when no models to import' do
        result = subject.call

        expect(result).to be(true)
      end
    end
  end
end

RSpec.describe Llm::ModelImporter do
  subject { described_class.new(model_config) }

  describe '#call' do
    let(:model_config) { { 'id' => 'gpt-4', 'tier' => 'premium' } }
    let(:standard_price) { double('input_per_million' => 10.0, 'output_per_million' => 30.0) }
    let(:pricing) { double(text_tokens: double(standard: standard_price)) }
    let(:ruby_llm_model) do
      double(id: 'model-123',
              capabilities: [ 'text', 'vision' ],
              context_window: 128000,
              family: 'gpt-4',
              knowledge_cutoff: '2024-04-01',
              name: 'GPT-4 Turbo',
              max_output_tokens: 4096,
              provider: 'openai',
              metadata: { supported_parameters: [ 'temperature', 'top_p' ] },
              pricing: pricing
      )
    end
    let(:llm_model) { double('LlmModel') }

    context 'when ruby llm model exists' do
      before do
        allow(subject).to receive(:ruby_llm_model).and_return(ruby_llm_model)
      end

      it { expect { subject.call }.to change(LlmModel, :count).by(1) }
      it { expect(subject.call.free).to be_falsey }
      it { expect(subject.call.input_cost).to eq(standard_price.input_per_million) }
      it { expect(subject.call.output_cost).to eq(standard_price.output_per_million) }

      context "when pricing is unavailable" do
        let(:standard_price) { nil }

        it { expect { subject.call }.to change(LlmModel, :count).by(1) }
        it { expect(subject.call.free).to be_truthy }
      end
    end

    context 'when RubyLLM model is not found' do
      before do
        allow(RubyLLM.models).to receive(:find).and_raise(
          RubyLLM::ModelNotFoundError, 'Model not found'
        )
        allow(Rails.logger).to receive(:error)
      end

      it { expect(subject.call).to be_nil }
      it { expect { subject.call }.not_to change(LlmModel, :count) }

      it "logs the error" do
        subject.call
        expect(Rails.logger).to have_received(:error).with(/Model not found/)
      end
    end
  end
end
