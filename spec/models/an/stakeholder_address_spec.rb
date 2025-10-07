require 'rails_helper'

RSpec.describe An::StakeholderAddress, type: :model do
  describe 'associations' do
    it { should belong_to(:an_stakeholder).class_name('An::Stakeholder') }
  end

  describe 'validations' do
    subject { create(:an_stakeholder_address) }

    it { should validate_presence_of(:uid) }
    it { should validate_uniqueness_of(:uid) }
    it { should validate_presence_of(:an_stakeholder_id) }
  end
end
