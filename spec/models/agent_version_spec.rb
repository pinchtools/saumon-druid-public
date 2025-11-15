require 'rails_helper'

RSpec.describe AgentVersion, type: :model do
  describe 'associations' do
    it { should belong_to(:agent) }
    it { should have_many(:agent_version_llm_models).dependent(:destroy) }
    it { should have_many(:llm_models).through(:agent_version_llm_models) }
  end

  describe 'validations' do
    subject { create(:agent_version) }
    it { should validate_presence_of(:agent_id) }
    it { should validate_presence_of(:version) }
    it { should validate_uniqueness_of(:version).scoped_to(:agent_id) }
  end

  describe 'enabled associations' do
    let(:agent_version) { create(:agent_version) }

    describe '#enabled_agent_version_llm_models' do
      let!(:enabled_model) { create(:agent_version_llm_model, agent_version: agent_version, enabled: true) }
      let!(:disabled_model) { create(:agent_version_llm_model, agent_version: agent_version, enabled: false) }

      it 'returns only enabled agent_version_llm_models' do
        expect(agent_version.enabled_agent_version_llm_models).to include(enabled_model)
        expect(agent_version.enabled_agent_version_llm_models).not_to include(disabled_model)
      end

      it 'returns the correct count' do
        expect(agent_version.enabled_agent_version_llm_models.count).to eq(1)
      end
    end

    describe '#enabled_llm_models' do
      let(:llm_model1) { create(:llm_model) }
      let(:llm_model2) { create(:llm_model) }
      let!(:enabled_association) { create(:agent_version_llm_model, agent_version: agent_version, llm_model: llm_model1, enabled: true) }
      let!(:disabled_association) { create(:agent_version_llm_model, agent_version: agent_version, llm_model: llm_model2, enabled: false) }

      it 'returns only llm_models from enabled associations' do
        expect(agent_version.enabled_llm_models).to include(llm_model1)
        expect(agent_version.enabled_llm_models).not_to include(llm_model2)
      end

      it 'returns the correct count' do
        expect(agent_version.enabled_llm_models.count).to eq(1)
      end
    end
  end
end
