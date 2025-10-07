require 'rails_helper'

RSpec.describe An::Term, type: :model do
  describe 'associations' do
    it { should belong_to(:an_stakeholder).class_name('An::Stakeholder') }
    it { should belong_to(:an_body).class_name('An::Body') }
    it { should belong_to(:constituency).class_name('An::Body').optional }
    it { should belong_to(:deputy_term).class_name('An::Term').optional }
    it { should have_many(:subordinate_terms).class_name('An::Term').with_foreign_key(:deputy_term_id).dependent(:destroy) }
  end

  describe 'validations' do
    subject { create(:an_term) }

    it { should validate_presence_of(:uid) }
    it { should validate_uniqueness_of(:uid) }
    it { should validate_presence_of(:an_stakeholder_id) }
    it { should validate_presence_of(:an_body_id) }
  end
end
