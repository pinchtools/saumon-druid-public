require 'rails_helper'

RSpec.describe An::Stakeholder, type: :model do
  describe 'associations' do
    it { should have_many(:an_stakeholder_addresses).class_name('An::StakeholderAddress').with_foreign_key(:an_stakeholder_id).dependent(:destroy) }
    it { should have_many(:an_terms).class_name('An::Term').with_foreign_key(:an_stakeholder_id).dependent(:destroy) }
    it { should have_many(:an_substitutes).class_name('An::Substitute').with_foreign_key(:an_stakeholder_id).inverse_of(:an_stakeholder).dependent(:destroy) }
    it { should have_many(:corrections).class_name('An::Correction').dependent(:destroy) }
    it { should have_one(:an_search).class_name('An::Search').dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:uid) }
    it { should validate_uniqueness_of(:uid) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
  end

  describe '#name' do
    let(:stakeholder) { build(:an_stakeholder, first_name: 'Jean', last_name: 'Dupont') }

    it 'returns full name' do
      expect(stakeholder.name).to eq('Jean Dupont')
    end
  end

  describe '#current_top_position' do
    let(:stakeholder) { create(:an_stakeholder) }
    let!(:regular_active_term) { create(:an_term, an_stakeholder: stakeholder, start_date: 1.month.ago, end_date: nil) }
    let!(:top_past_term) { create(:an_term, :major_responsibility, an_stakeholder: stakeholder, start_date: 1.year.ago, end_date: 1.week.ago) }
    let!(:top_active_term) { create(:an_term, :major_responsibility, an_stakeholder: stakeholder, start_date: 1.month.ago, end_date: nil) }

    it 'returns the first active term by hierarchy' do
      expect(stakeholder.current_top_position).to eq(top_active_term)
    end

    context 'when an_terms are preloaded' do
      it 'returns the first active term by hierarchy using in-memory sorting' do
        preloaded_stakeholder = An::Stakeholder.includes(an_terms: { an_body: :an_body_type }).find(stakeholder.id)
        expect(preloaded_stakeholder.an_terms).to be_loaded
        expect(preloaded_stakeholder.current_top_position).to eq(top_active_term)
      end
    end
  end

  describe '#other_top_active_positions' do
    let(:stakeholder) { create(:an_stakeholder) }
    let!(:regular_active_term) { create(:an_term, an_stakeholder: stakeholder, start_date: 1.month.ago, end_date: nil) }
    let!(:top_active_term) { create(:an_term, :major_responsibility, an_stakeholder: stakeholder, start_date: 1.month.ago, end_date: nil) }

    it 'returns active terms except top one' do
      expect(stakeholder.other_top_active_positions).to eq([ regular_active_term ])
    end

    context 'when an_terms are preloaded' do
      it 'returns active terms except top one using in-memory filtering' do
        preloaded_stakeholder = An::Stakeholder.includes(an_terms: { an_body: :an_body_type }).find(stakeholder.id)
        expect(preloaded_stakeholder.an_terms).to be_loaded
        expect(preloaded_stakeholder.other_top_active_positions).to eq([ regular_active_term ])
      end

      it 'respects offset and limit parameters with preloaded data' do
        second_term = create(:an_term, an_stakeholder: stakeholder, start_date: 2.months.ago, end_date: nil)
        third_term = create(:an_term, an_stakeholder: stakeholder, start_date: 3.months.ago, end_date: nil)

        preloaded_stakeholder = An::Stakeholder.includes(an_terms: { an_body: :an_body_type }).find(stakeholder.id)
        expect(preloaded_stakeholder.an_terms).to be_loaded

        result = preloaded_stakeholder.other_top_active_positions(offset: 2, limit: 2)
        expect(result).to eq([ second_term, third_term ])
      end
    end
  end

  describe '#top_past_positions' do
    let(:stakeholder) { create(:an_stakeholder) }
    let!(:top_past_term) { create(:an_term, :major_responsibility, an_stakeholder: stakeholder, start_date: 1.year.ago, end_date: 1.week.ago) }
    let!(:top_active_term) { create(:an_term, :major_responsibility, an_stakeholder: stakeholder, start_date: 1.month.ago, end_date: nil) }

    it 'only returns past positions' do
      expect(stakeholder.top_past_positions).to eq([ top_past_term ])
    end

    context 'when an_terms are preloaded' do
      it 'only returns past positions using in-memory filtering' do
        preloaded_stakeholder = An::Stakeholder.includes(an_terms: { an_body: :an_body_type }).find(stakeholder.id)
        expect(preloaded_stakeholder.an_terms).to be_loaded
        expect(preloaded_stakeholder.top_past_positions).to eq([ top_past_term ])
      end

      it 'respects limit parameter with preloaded data' do
        second_past_term = create(:an_term, an_stakeholder: stakeholder, start_date: 2.years.ago, end_date: 1.year.ago)
        third_past_term = create(:an_term, an_stakeholder: stakeholder, start_date: 3.years.ago, end_date: 2.years.ago)

        preloaded_stakeholder = An::Stakeholder.includes(an_terms: { an_body: :an_body_type }).find(stakeholder.id)
        expect(preloaded_stakeholder.an_terms).to be_loaded

        result = preloaded_stakeholder.top_past_positions(limit: 2)
        expect(result).to contain_exactly(top_past_term, second_past_term)
      end
    end
  end
end
