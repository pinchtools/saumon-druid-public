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
  end

  describe '#other_top_active_positions' do
    let(:stakeholder) { create(:an_stakeholder) }
    let!(:regular_active_term) { create(:an_term, an_stakeholder: stakeholder, start_date: 1.month.ago, end_date: nil) }
    let!(:top_active_term) { create(:an_term, :major_responsibility, an_stakeholder: stakeholder, start_date: 1.month.ago, end_date: nil) }

    it 'returns active terms except top one' do
      expect(stakeholder.other_top_active_positions).to eq([ regular_active_term ])
    end
  end

  describe '#top_past_positions' do
    let(:stakeholder) { create(:an_stakeholder) }
    let!(:top_past_term) { create(:an_term, :major_responsibility, an_stakeholder: stakeholder, start_date: 1.year.ago, end_date: 1.week.ago) }
    let!(:top_active_term) { create(:an_term, :major_responsibility, an_stakeholder: stakeholder, start_date: 1.month.ago, end_date: nil) }

    it 'only returns past positions' do
      expect(stakeholder.top_past_positions).to eq([ top_past_term ])
    end
  end
end
