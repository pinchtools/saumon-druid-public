require 'rails_helper'

RSpec.describe AgentVersion, type: :model do
  describe 'associations' do
     it { should belong_to(:agent) }
  end
end
