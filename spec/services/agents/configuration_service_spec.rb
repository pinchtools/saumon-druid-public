require 'rails_helper'

RSpec.describe Agents::ConfigurationService do
  let(:agent_name) { "test_agent" }
  let(:agent_description) { "A test agent" }
  let(:agent_role) { "Test role" }
  let(:agent_directives) { "Test directives" }
  let(:agent_instructions) { "#{agent_role}\n\n#{agent_directives}" }
  let(:hyperparams) { { "temperature" => 0.1 } }
  let(:gpt_35_turbo) { "gpt-3.5-turbo" }
  let(:gpt_4) { "gpt-4" }
  let(:default_models) { [ gpt_35_turbo ] }

  let(:valid_yaml) do
    {
      "agent" => {
        "name" => agent_name,
        "description" => agent_description,
        "role" => agent_role,
        "directives" => agent_directives,
        "models" => default_models,
        "hyperparams" => hyperparams
      }
    }
  end

  describe '#initialize' do
    it 'validates and stores YAML data' do
      service = described_class.new(valid_yaml)
      expect(service.yaml["name"]).to eq(agent_name)
    end

    it 'raises error for invalid YAML' do
      invalid_yaml = { "invalid" => "structure" }
      expect { described_class.new(invalid_yaml) }.to raise_error(ArgumentError)
    end
  end

  describe '#call' do
    let!(:llm_model) { create(:llm_model, external_id: gpt_35_turbo) }
    let!(:gpt4_model) { create(:llm_model, external_id: gpt_4) }
    let(:service) { described_class.new(valid_yaml) }

    context 'with new agent' do
      it 'creates agent and agent_version' do
        expect { service.call }.to change(Agent, :count).by(1)
          .and change(AgentVersion, :count).by(1)
      end

      it 'returns success result' do
        result = service.call
        expect(result).to be_a(Agents::ConfigurationResult)
        expect(result.success?).to be true
      end
    end

    shared_examples 'an existing agent setup' do
      let!(:existing_agent) { create(:agent, name: agent_name, description: agent_description) }

      before { existing_agent.update!(current_agent_version: existing_version) }
    end

    context 'with existing agent and no changes' do
      include_examples 'an existing agent setup'

      let!(:existing_version) do
        create(:agent_version, agent: existing_agent, instructions: agent_instructions, hyperparams: hyperparams)
      end

      before { create(:agent_version_llm_model, agent_version: existing_version, llm_model: llm_model, priority: 1) }

      it 'does not create new version when unchanged' do
        expect { service.call }.not_to change(AgentVersion, :count)
      end
    end

    context 'with existing agent and instruction changes' do
      include_examples 'an existing agent setup'

      let!(:existing_version) { create(:agent_version, agent: existing_agent, instructions: "old instructions") }

      it 'creates new version when changed' do
        expect { service.call }.to change(AgentVersion, :count).by(1)
      end

      it 'updates current_agent_version' do
        service.call
        expect(existing_agent.reload.current_agent_version.instructions).to include(agent_role)
      end
    end

    context 'model list changes' do
      include_examples 'an existing agent setup'

      let!(:existing_version) do
        create(:agent_version, agent: existing_agent, instructions: agent_instructions, hyperparams: hyperparams)
      end

      context 'when models change' do
        before { create(:agent_version_llm_model, agent_version: existing_version, llm_model: gpt4_model, priority: 1) }

        it 'creates new version when models are different' do
          expect { service.call }.to change(AgentVersion, :count).by(1)
        end

        it 'updates to new model list' do
          service.call
          new_version = existing_agent.reload.current_agent_version

          expect(new_version.enabled_llm_models.pluck(:external_id)).to eq([ gpt_35_turbo ])
          expect(new_version.enabled_llm_models.first.external_id).not_to eq(gpt_4)
        end
      end

      context 'when models stay the same' do
        before { create(:agent_version_llm_model, agent_version: existing_version, llm_model: llm_model, priority: 1) }

        it 'does not create new version' do
          expect { service.call }.not_to change(AgentVersion, :count)
        end

        it 'preserves existing model associations' do
          original_count = existing_version.agent_version_llm_models.count
          service.call

          expect(existing_version.reload.agent_version_llm_models.count).to eq(original_count)
          expect(existing_version.enabled_llm_models.first.external_id).to eq(gpt_35_turbo)
        end
      end

      context 'with multiple models' do
        let(:multi_models_yaml) { valid_yaml.deep_merge("agent" => { "models" => [ gpt_4, gpt_35_turbo ] }) }
        let(:multi_service) { described_class.new(multi_models_yaml) }

        before { create(:agent_version_llm_model, agent_version: existing_version, llm_model: llm_model, priority: 1) }

        it 'maintains correct priority order' do
          multi_service.call
          new_version = existing_agent.reload.current_agent_version

          priorities = new_version.agent_version_llm_models.order(:priority).pluck(:priority)
          model_ids = new_version.agent_version_llm_models.order(:priority).joins(:llm_model).pluck('llm_models.external_id')

          expect(priorities).to eq([ 1, 2 ])
          expect(model_ids).to eq([ gpt_4, gpt_35_turbo ])
        end
      end
    end
  end
end

RSpec.describe Agents::InstructionBuilder do
  let(:yaml_data) do
    {
      "role" => "Test role",
      "directives" => "Test directives",
      "context_format" => '[{"key": "test"}]'
    }
  end

  describe '#to_s' do
    it 'combines role, directives, and context_format' do
      builder = described_class.new(yaml_data)
      result = builder.to_s

      expect(result).to include("Test role")
      expect(result).to include("Test directives")
      expect(result).to include("CONTEXT FORMAT")
    end

    it 'handles missing context_format' do
      yaml_without_context = yaml_data.except("context_format")
      builder = described_class.new(yaml_without_context)
      result = builder.to_s

      expect(result).to include("Test role")
      expect(result).not_to include("CONTEXT FORMAT")
    end
  end
end

RSpec.describe Agents::ConfigurationResult do
  describe '#success?' do
    it 'always returns true' do
      result = described_class.new(agent_changed: true, agent_version_changed: false)
      expect(result.success?).to be true
    end
  end

  describe 'attribute accessors' do
    let(:result) { described_class.new(agent_changed: true, agent_version_changed: false) }

    it 'provides predicate methods' do
      expect(result.agent_changed?).to be true
      expect(result.agent_version_changed?).to be false
    end

    it 'provides attribute readers' do
      expect(result.agent_changed).to be true
      expect(result.agent_version_changed).to be false
    end
  end
end
