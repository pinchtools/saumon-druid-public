require 'rails_helper'

RSpec.describe An::Stakeholder, type: :model do
  describe 'associations' do
    it { should have_many(:an_stakeholder_addresses).class_name('An::StakeholderAddress').with_foreign_key(:an_stakeholder_id).dependent(:destroy) }
    it { should have_many(:an_terms).class_name('An::Term').with_foreign_key(:an_stakeholder_id).dependent(:destroy) }
    it { should have_many(:an_substitutes).class_name('An::Substitute').with_foreign_key(:an_stakeholder_id).inverse_of(:an_stakeholder).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:uid) }
    it { should validate_uniqueness_of(:uid) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
  end
end
