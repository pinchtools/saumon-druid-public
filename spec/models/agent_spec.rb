require 'rails_helper'

RSpec.describe Agent, type: :model do
  describe 'associations' do
    it { should have_many(:agent_versions) }
    it { should belong_to(:current_agent_version).class_name("AgentVersion").optional }
  end

  describe 'validations' do
    subject do
      described_class.new(
        name: 'Test Agent',
        normalized_name: 'test_agent'
      )
    end

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:normalized_name).case_insensitive }

    describe "current_agent_version must belongs to agent" do
      context "current_agent_version belongs to agent" do
        subject { create(:agent) }
        let(:current_agent_version) { create(:agent_version, agent: subject) }

        before { subject.current_agent_version = current_agent_version }

        it { should be_valid }
      end

      context "current_agent_version does not belong to agent" do
        subject { create(:agent) }
        let(:current_agent_version) { create(:agent_version) }

        before { subject.current_agent_version = current_agent_version }

        it { should_not be_valid }
        it "should add an error on current_agent_version" do
          subject.valid?
          expect(subject.errors[:current_agent_version]).to include("does not belong to agent")
          end
      end
    end
  end

  describe 'normalized_name' do
    it 'is automatically set from name' do
      agent = described_class.new(name: 'Test Agent')
      agent.valid?
      expect(agent.normalized_name).to eq('test_agent')
    end

    it 'is required when name is not present' do
      agent = described_class.new(name: nil)
      expect(agent).not_to be_valid
      expect(agent.errors[:normalized_name]).to include("can't be blank")
    end
  end
end
