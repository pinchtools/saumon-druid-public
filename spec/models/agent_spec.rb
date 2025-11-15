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
