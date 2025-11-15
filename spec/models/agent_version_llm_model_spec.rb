require 'rails_helper'

RSpec.describe AgentVersionLlmModel, type: :model do
  describe 'associations' do
    it { should belong_to(:agent_version) }
    it { should belong_to(:llm_model) }
  end

  describe 'validations' do
    subject { create(:agent_version_llm_model) }

    it { should validate_presence_of(:agent_version) }
    it { should validate_presence_of(:llm_model) }
    it { should validate_presence_of(:priority) }
    it { should validate_uniqueness_of(:llm_model).scoped_to(:agent_version_id) }
    it { should validate_uniqueness_of(:priority).scoped_to(:agent_version_id) }
    it { should validate_numericality_of(:priority).only_integer }
  end

  describe 'scopes' do
    describe '.by_priority' do
      let!(:high_priority) { create(:agent_version_llm_model, priority: 1) }
      let!(:low_priority) { create(:agent_version_llm_model, priority: 3) }
      let!(:medium_priority) { create(:agent_version_llm_model, priority: 2) }

      it 'returns records ordered by priority ascending' do
        expect(described_class.by_priority).to eq([ high_priority, medium_priority, low_priority ])
      end
    end

    describe '.enabled' do
      context 'when the llm model is enabled for this agent version' do
        subject { create(:agent_version_llm_model, enabled: true) }
        it { expect(described_class.enabled).to include(subject) }
      end

      context 'when the llm model is disabled for this agent version' do
        subject { create(:agent_version_llm_model, enabled: false) }

        it { expect(described_class.enabled).not_to include(subject) }
      end
    end
  end
end
