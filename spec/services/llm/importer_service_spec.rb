# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Llm::ImporterService do
  subject { described_class.new }

  describe '#call' do
    let(:yaml_content) do
      {
        'openai' => [ { 'id' => 'gpt-4', 'tier' => 'strong' } ],
        'anthropic' => [ { 'id' => 'claude-3', 'tier' => 'top' } ]
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
        expect(Llm::ModelImporter).to receive(:new).with({ 'id' => 'gpt-4', 'tier' => 'strong' })
        expect(Llm::ModelImporter).to receive(:new).with({ 'id' => 'claude-3', 'tier' => 'top' })

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
