RSpec.describe Llm::ModelImporter do
  subject { described_class.new(model_config) }

  describe '#call' do
    let(:model_config) { { 'id' => 'gpt-4', 'tier' => 'strong' } }
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
