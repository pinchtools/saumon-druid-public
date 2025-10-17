require 'rails_helper'

RSpec.describe An::Term, type: :model do
  describe 'associations' do
    it { should belong_to(:an_stakeholder).class_name('An::Stakeholder') }
    it { should belong_to(:an_body).class_name('An::Body') }
    it { should belong_to(:constituency).class_name('An::Body').optional }
    it { should belong_to(:deputy_term).class_name('An::Term').optional }
    it { should have_many(:subordinate_terms).class_name('An::Term').with_foreign_key(:deputy_term_id).dependent(:destroy) }
    it { should have_one(:an_body_type).through(:an_body) }
  end

  describe 'scopes' do
    describe '.main' do
      let!(:main_term) { create(:an_term, :main_term) }
      let!(:non_main_term) { create(:an_term, main: false) }

      it 'returns only main terms' do
        expect(An::Term.main).to include(main_term)
        expect(An::Term.main).not_to include(non_main_term)
      end
    end

    describe '.active' do
      let!(:active_term) { create(:an_term, start_date: 1.month.ago, end_date: nil) }
      let!(:ended_term) { create(:an_term, start_date: 1.month.ago, end_date: 1.week.ago) }
      let!(:future_term) { create(:an_term, start_date: nil, end_date: nil) }

      it 'returns terms with start_date and no end_date' do
        expect(An::Term.active).to include(active_term)
        expect(An::Term.active).not_to include(ended_term)
        expect(An::Term.active).not_to include(future_term)
      end
    end

    describe '.by_hierarchy' do
      let!(:body_type_low) { create(:an_body_type, hierarchy_level: 1) }
      let!(:body_type_high) { create(:an_body_type, hierarchy_level: 3) }
      let!(:body_type_mid) { create(:an_body_type, hierarchy_level: 2) }

      let!(:body_low) { create(:an_body, an_body_type: body_type_low) }
      let!(:body_high) { create(:an_body, an_body_type: body_type_high) }
      let!(:body_mid) { create(:an_body, an_body_type: body_type_mid) }

      let!(:term_low) { create(:an_term, an_body: body_low) }
      let!(:term_high) { create(:an_term, an_body: body_high) }
      let!(:term_mid) { create(:an_term, an_body: body_mid) }

      it 'orders terms by hierarchy_level ascending' do
        ordered_terms = An::Term.by_hierarchy
        expect(ordered_terms.first).to eq(term_low)
        expect(ordered_terms.second).to eq(term_mid)
        expect(ordered_terms.third).to eq(term_high)
      end

      it 'includes all terms with hierarchy levels' do
        expect(An::Term.by_hierarchy).to include(term_low, term_mid, term_high)
      end
    end
  end

  describe 'validations' do
    subject { create(:an_term) }

    it { should validate_presence_of(:uid) }
    it { should validate_uniqueness_of(:uid) }
    it { should validate_presence_of(:an_stakeholder_id) }
    it { should validate_presence_of(:an_body_id) }
  end
end
