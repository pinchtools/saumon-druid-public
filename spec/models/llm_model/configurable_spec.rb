require 'rails_helper'

RSpec.describe LlmModel::Configurable do
  describe '.configure_from_yaml' do
    let(:model_config) { { 'id' => 'gpt-4', 'tier' => 'strong' } }
    let(:standard_price) { double('input_per_million' => 10.0, 'output_per_million' => 30.0) }
    let(:pricing) { double(text_tokens: double(standard: standard_price)) }
    let(:ruby_llm_model) do
      double(
        id: 'model-123',
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

    context 'when ruby llm model exists' do
      before do
        allow(RubyLLM.models).to receive(:find).with('gpt-4').and_return(ruby_llm_model)
      end

      it { expect { LlmModel.configure_from_yaml(model_config) }.to change(LlmModel, :count).by(1) }

      it 'returns the configured model' do
        result = LlmModel.configure_from_yaml(model_config)
        expect(result).to be_a(LlmModel)
        expect(result).to be_persisted
      end

      it 'sets free to false when pricing exists' do
        result = LlmModel.configure_from_yaml(model_config)
        expect(result.free).to be_falsey
      end

      it 'sets input_cost from pricing' do
        result = LlmModel.configure_from_yaml(model_config)
        expect(result.input_cost).to eq(standard_price.input_per_million)
      end

      it 'sets output_cost from pricing' do
        result = LlmModel.configure_from_yaml(model_config)
        expect(result.output_cost).to eq(standard_price.output_per_million)
      end

      it 'sets tier from config' do
        result = LlmModel.configure_from_yaml(model_config)
        expect(result.tier).to eq('strong')
      end

      context 'when pricing is unavailable' do
        let(:standard_price) { nil }

        it { expect { LlmModel.configure_from_yaml(model_config) }.to change(LlmModel, :count).by(1) }

        it 'sets free to true' do
          result = LlmModel.configure_from_yaml(model_config)
          expect(result.free).to be_truthy
        end

        it 'sets costs to nil' do
          result = LlmModel.configure_from_yaml(model_config)
          expect(result.input_cost).to be_nil
          expect(result.output_cost).to be_nil
        end
      end

      context 'when model already exists' do
        let!(:existing_model) { create(:llm_model, external_id: 'model-123', tier: 'medium') }

        it 'updates the existing model' do
          expect { LlmModel.configure_from_yaml(model_config) }.not_to change(LlmModel, :count)
        end

        it 'updates the tier' do
          LlmModel.configure_from_yaml(model_config)
          expect(existing_model.reload.tier).to eq('strong')
        end
      end
    end

    context 'when RubyLLM model is not found' do
      before do
        allow(RubyLLM.models).to receive(:find).and_raise(
          RubyLLM::ModelNotFoundError, 'Model not found'
        )
        allow(Rails.logger).to receive(:error)
      end

      it { expect(LlmModel.configure_from_yaml(model_config)).to be_nil }
      it { expect { LlmModel.configure_from_yaml(model_config) }.not_to change(LlmModel, :count) }

      it 'logs the error' do
        LlmModel.configure_from_yaml(model_config)
        expect(Rails.logger).to have_received(:error).with(/Model not found/)
      end
    end
  end
end
