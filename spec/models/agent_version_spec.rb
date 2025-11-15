require 'rails_helper'

RSpec.describe AgentVersion, type: :model do
  describe 'associations' do
     it { should belong_to(:agent) }
  end

  describe 'validations' do
    subject { create(:agent_version) }
    it { should validate_presence_of(:agent_id) }
    it { should validate_presence_of(:version) }
    it { should validate_uniqueness_of(:version).scoped_to(:agent_id) }
  end
end
