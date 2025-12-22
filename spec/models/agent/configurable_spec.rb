require 'rails_helper'

RSpec.describe Agent::Configurable do
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

  describe '.configure_from_yaml' do
    let!(:llm_model) { create(:llm_model, external_id: gpt_35_turbo) }
    let!(:gpt4_model) { create(:llm_model, external_id: gpt_4) }

    it 'validates YAML data' do
      result = Agent.configure_from_yaml(valid_yaml)
      expect(result.agent.name).to eq(agent_name)
    end

    it 'raises error for invalid YAML' do
      invalid_yaml = { "invalid" => "structure" }
      expect { Agent.configure_from_yaml(invalid_yaml) }.to raise_error(ArgumentError)
    end

    context 'with new agent' do
      it 'creates agent and agent_version' do
        expect { Agent.configure_from_yaml(valid_yaml) }
          .to change(Agent, :count).by(1)
          .and change(AgentVersion, :count).by(1)
      end

      it 'returns success result' do
        result = Agent.configure_from_yaml(valid_yaml)
        expect(result).to be_a(Agent::Configurable::Result)
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
        expect { Agent.configure_from_yaml(valid_yaml) }.not_to change(AgentVersion, :count)
      end
    end

    context 'with existing agent and instruction changes' do
      include_examples 'an existing agent setup'

      let!(:existing_version) { create(:agent_version, agent: existing_agent, instructions: "old instructions") }

      it 'creates new version when changed' do
        expect { Agent.configure_from_yaml(valid_yaml) }.to change(AgentVersion, :count).by(1)
      end

      it 'updates current_agent_version' do
        Agent.configure_from_yaml(valid_yaml)
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
          expect { Agent.configure_from_yaml(valid_yaml) }.to change(AgentVersion, :count).by(1)
        end

        it 'updates to new model list' do
          Agent.configure_from_yaml(valid_yaml)
          new_version = existing_agent.reload.current_agent_version

          expect(new_version.enabled_llm_models.pluck(:external_id)).to eq([ gpt_35_turbo ])
          expect(new_version.enabled_llm_models.first.external_id).not_to eq(gpt_4)
        end
      end

      context 'when models stay the same' do
        before { create(:agent_version_llm_model, agent_version: existing_version, llm_model: llm_model, priority: 1) }

        it 'does not create new version' do
          expect { Agent.configure_from_yaml(valid_yaml) }.not_to change(AgentVersion, :count)
        end

        it 'preserves existing model associations' do
          original_count = existing_version.agent_version_llm_models.count
          Agent.configure_from_yaml(valid_yaml)

          expect(existing_version.reload.agent_version_llm_models.count).to eq(original_count)
          expect(existing_version.enabled_llm_models.first.external_id).to eq(gpt_35_turbo)
        end
      end

      context 'with multiple models' do
        let(:multi_models_yaml) { valid_yaml.deep_merge("agent" => { "models" => [ gpt_4, gpt_35_turbo ] }) }

        before { create(:agent_version_llm_model, agent_version: existing_version, llm_model: llm_model, priority: 1) }

        it 'maintains correct priority order' do
          Agent.configure_from_yaml(multi_models_yaml)
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
