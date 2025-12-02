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
    it { should validate_presence_of(:address_type) }
    it { should validate_inclusion_of(:address_type).in_array(described_class::ADDRESS_TYPES) }
  end
end
